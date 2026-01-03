#!/bin/bash

# --- Cores ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}[*] Iniciando instalação das dependências para 'muuf'...${NC}"

# Atualizar sistema
sudo apt update

# Instalar Go se não existir
if ! command -v go &> /dev/null; then
    echo -e "${YELLOW}[*] Instalando Go...${NC}"
    sudo apt install golang -y
fi

# Configurar PATH do Go
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
echo 'export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' >> ~/.bashrc

# Instalar ferramentas ProjectDiscovery
echo -e "${YELLOW}[*] Instalando ferramentas do ProjectDiscovery (subfinder, httpx, nuclei, naabu)...${NC}"
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest

# Instalar Amass
echo -e "${YELLOW}[*] Instalando Amass...${NC}"
sudo apt install amass -y

# Instalar Gowitness
echo -e "${YELLOW}[*] Instalando Gowitness...${NC}"
go install github.com/sensepost/gowitness@latest

# Dar permissão de execução ao script principal
chmod +x muuf.sh

echo -e "${GREEN}[V] Instalação concluída!${NC}"
echo -e "${YELLOW}[!] Reinicie seu terminal ou execute 'source ~/.bashrc' para atualizar o PATH.${NC}"
echo -e "${GREEN}[+] Para usar, execute: ./muuf.sh${NC}"
