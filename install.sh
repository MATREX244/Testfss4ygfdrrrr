#!/bin/bash

# =============================================================================
# Script de Instalação do muuf - Bug Bounty Hunter Tool
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "=============================================="
echo "  Instalador do muuf v1.0.0"
echo "  Bug Bounty Hunter Tool"
echo "=============================================="
echo -e "${NC}\n"

# Verificar se está rodando como root (para apt-get)
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}[!] Este script precisa de privilégios sudo para instalar algumas ferramentas.${NC}"
    echo -e "${YELLOW}[!] Você será solicitado a inserir sua senha quando necessário.${NC}\n"
fi

# Função de log
log_install() {
    echo -e "${GREEN}[+]${NC} $1"
}

log_error() {
    echo -e "${RED}[!]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[*]${NC} $1"
}

# 1. Atualizar repositórios
log_info "Atualizando repositórios do sistema..."
sudo apt-get update -qq

# 2. Instalar dependências básicas
log_install "Instalando dependências básicas..."
sudo apt-get install -y curl wget git jq python3 python3-pip golang-go build-essential -qq

# 3. Verificar e configurar Go
log_info "Verificando instalação do Go..."
if ! command -v go &> /dev/null; then
    log_error "Go não está instalado corretamente."
    exit 1
fi

# Configurar GOPATH se não estiver configurado
if [ -z "$GOPATH" ]; then
    export GOPATH=$HOME/go
    export PATH=$PATH:$GOPATH/bin
    if ! grep -q 'export GOPATH=$HOME/go' ~/.bashrc; then
        echo 'export GOPATH=$HOME/go' >> ~/.bashrc
        echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
    fi
    log_info "GOPATH configurado em $GOPATH"
fi

# 4. Instalar ferramentas Go (ProjectDiscovery)
log_install "Instalando ferramentas do ProjectDiscovery..."

# Subfinder
if ! command -v subfinder &> /dev/null; then
    log_install "Instalando Subfinder..."
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
else
    log_info "Subfinder já instalado."
fi

# httpx
if ! command -v httpx &> /dev/null; then
    log_install "Instalando httpx..."
    go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
else
    log_info "httpx já instalado."
fi

# Naabu
if ! command -v naabu &> /dev/null; then
    log_install "Instalando Naabu..."
    go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
else
    log_info "Naabu já instalado."
fi

# Nuclei
if ! command -v nuclei &> /dev/null; then
    log_install "Instalando Nuclei..."
    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
    # Atualizar templates do Nuclei
    log_info "Atualizando templates do Nuclei..."
    nuclei -update-templates
else
    log_info "Nuclei já instalado."
fi

# Katana
if ! command -v katana &> /dev/null; then
    log_install "Instalando Katana..."
    go install -v github.com/projectdiscovery/katana/cmd/katana@latest
else
    log_info "Katana já instalado."
fi

# 5. Instalar outras ferramentas Go
log_install "Instalando outras ferramentas Go..."

# Assetfinder
if ! command -v assetfinder &> /dev/null; then
    log_install "Instalando Assetfinder..."
    go install -v github.com/tomnomnom/assetfinder@latest
else
    log_info "Assetfinder já instalado."
fi

# ffuf
if ! command -v ffuf &> /dev/null; then
    log_install "Instalando ffuf..."
    go install -v github.com/ffuf/ffuf/v2@latest
else
    log_info "ffuf já instalado."
fi

# Gowitness
if ! command -v gowitness &> /dev/null; then
    log_install "Instalando Gowitness..."
    go install -v github.com/sensepost/gowitness@latest
else
    log_info "Gowitness já instalado."
fi

# Subjack
if ! command -v subjack &> /dev/null; then
    log_install "Instalando Subjack..."
    go install -v github.com/haccer/subjack@latest
    
    # Baixar fingerprints do subjack
    mkdir -p ~/.config/subjack
    if [ ! -f ~/.config/subjack/fingerprints.json ]; then
        log_info "Baixando fingerprints do Subjack..."
        wget -q https://raw.githubusercontent.com/haccer/subjack/master/fingerprints.json -O ~/.config/subjack/fingerprints.json
    fi
else
    log_info "Subjack já instalado."
fi

# 6. Instalar ferramentas via apt
log_install "Instalando ferramentas via apt..."

# Amass
if ! command -v amass &> /dev/null; then
    log_install "Instalando Amass..."
    sudo apt-get install -y amass -qq
else
    log_info "Amass já instalado."
fi

# WhatWeb
if ! command -v whatweb &> /dev/null; then
    log_install "Instalando WhatWeb..."
    sudo apt-get install -y whatweb -qq
else
    log_info "WhatWeb já instalado."
fi

# 7. Criar diretórios necessários
log_info "Criando estrutura de diretórios..."
mkdir -p ./results
mkdir -p ./.cache

# 8. Baixar wordlists comuns
log_install "Configurando wordlists..."
if [ ! -d "/usr/share/wordlists" ]; then
    sudo mkdir -p /usr/share/wordlists
fi

if [ ! -d "/usr/share/wordlists/dirb" ]; then
    log_install "Baixando wordlist dirb/common.txt..."
    sudo mkdir -p /usr/share/wordlists/dirb
    sudo wget -q https://raw.githubusercontent.com/v0re/dirb/master/wordlists/common.txt -O /usr/share/wordlists/dirb/common.txt
fi

# 9. Verificação final
log_info "\nVerificando instalação..."

TOOLS=("subfinder" "httpx" "naabu" "nuclei" "katana" "assetfinder" "ffuf" "gowitness" "subjack" "amass" "whatweb" "jq" "curl")
MISSING=()

for tool in "${TOOLS[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $tool"
    else
        echo -e "${RED}✗${NC} $tool"
        MISSING+=("$tool")
    fi
done

echo ""

if [ ${#MISSING[@]} -eq 0 ]; then
    echo -e "${GREEN}=============================================="
    echo -e "  Instalação concluída com sucesso!"
    echo -e "  Todas as ferramentas foram instaladas."
    echo -e "==============================================${NC}\n"
    echo -e "${YELLOW}Para começar a usar o muuf, execute:${NC}"
    echo -e "${BLUE}  ./muuf.sh -d example.com${NC}\n"
    echo -e "${YELLOW}Para ver todas as opções:${NC}"
    echo -e "${BLUE}  ./muuf.sh --help${NC}\n"
else
    echo -e "${YELLOW}=============================================="
    echo -e "  Instalação concluída com avisos"
    echo -e "  Ferramentas faltando: ${MISSING[*]}"
    echo -e "==============================================${NC}\n"
    echo -e "${YELLOW}Tente instalar manualmente as ferramentas faltando.${NC}\n"
fi

# 10. Tornar muuf.sh executável
if [ -f "./muuf.sh" ]; then
    chmod +x ./muuf.sh
    log_info "Permissões de execução concedidas ao muuf.sh"
fi

exit 0
