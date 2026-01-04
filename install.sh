#!/bin/bash

# =============================================================================
# muuf PRO - Script de Instalação de Dependências
# =============================================================================

echo -e "\033[0;36m[*] Iniciando a instalação das dependências do muuf PRO...\033[0m"

# Atualizar sistema e instalar dependências básicas (jq, curl, git)
sudo apt-get update && sudo apt-get install -y golang jq curl git

# Configurar ambiente Go (essencial para as ferramentas)
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin

# Adicionar ao .bashrc e .zshrc para que o PATH seja permanente
if ! grep -q "GOPATH" ~/.bashrc; then
    echo -e "\n# --- Go Environment ---" >> ~/.bashrc
    echo 'export GOPATH=$HOME/go' >> ~/.bashrc
    echo 'export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' >> ~/.bashrc
fi

if [ -f "~/.zshrc" ] && ! grep -q "GOPATH" ~/.zshrc; then
    echo -e "\n# --- Go Environment ---" >> ~/.zshrc
    echo 'export GOPATH=$HOME/go' >> ~/.zshrc
    echo 'export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' >> ~/.zshrc
fi

# Instalar ferramentas do ProjectDiscovery
echo -e "\033[0;35m[*] Instalando ferramentas do ProjectDiscovery...\033[0m"
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install -v github.com/projectdiscovery/katana/cmd/katana@latest
go install -v github.com/projectdiscovery/notify/cmd/notify@latest

# Instalar outras ferramentas essenciais
echo -e "\033[0;35m[*] Instalando outras ferramentas essenciais...\033[0m"
go install -v github.com/tomnomnom/assetfinder@latest
go install -v github.com/tomnomnom/anew@latest
go install -v github.com/lc/gau/v2/cmd/gau@latest
go install -v github.com/ffuf/ffuf/v2@latest

# Dar permissão de execução ao script principal
chmod +x muuf_pro.sh

echo -e "\033[0;32m[+] Instalação concluída com sucesso!\033[0m"
echo -e "\033[1;33m[!] IMPORTANTE: Rode o comando 'source ~/.bashrc' ou reinicie seu terminal para que as ferramentas sejam reconhecidas.\033[0m"
