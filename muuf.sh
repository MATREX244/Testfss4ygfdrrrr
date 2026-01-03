#!/bin/bash

# --- Cores para o Terminal ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sem cor

# --- Banner ---
echo -e "${BLUE}"
echo "  __  __ _    _ _    _ ______ "
echo " |  \/  | |  | | |  | |  ____|"
echo " | \  / | |  | | |  | | |__   "
echo " | |\/| | |  | | |  | |  __|  "
echo " | |  | | |__| | |__| | |     "
echo " |_|  |_|\____/ \____/|_|     "
echo -e "      Ferramenta de Automação Bug Hunter (muuf)${NC}\n"

# --- Função de Verificação de Ferramentas ---
check_tool() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}[!] Erro: $1 não está instalado.${NC}"
        return 1
    fi
    return 0
}

# --- Entrada do Usuário ---
read -p "Digite o domínio alvo (ex: exemplo.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}[!] Domínio não pode ser vazio.${NC}"
    exit 1
fi

# --- Criação de Diretórios ---
DATE=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="results_${DOMAIN}_${DATE}"
mkdir -p "$OUTPUT_DIR"/{subdomains,ports,tech,nuclei,screenshots}

echo -e "${GREEN}[+] Iniciando automação para: $DOMAIN${NC}"
echo -e "${YELLOW}[*] Resultados serão salvos em: $OUTPUT_DIR${NC}\n"

# --- 1. Descoberta de Subdomínios ---
echo -e "${BLUE}[1/6] Buscando subdomínios com Subfinder...${NC}"
subfinder -d "$DOMAIN" -o "$OUTPUT_DIR/subdomains/subfinder.txt" -silent

echo -e "${BLUE}[1/6] Buscando subdomínios com Amass (Passive)...${NC}"
amass enum -passive -d "$DOMAIN" -o "$OUTPUT_DIR/subdomains/amass.txt"

cat "$OUTPUT_DIR/subdomains/"*.txt | sort -u > "$OUTPUT_DIR/subdomains/all_subdomains.txt"
echo -e "${GREEN}[V] Total de subdomínios únicos: $(wc -l < "$OUTPUT_DIR/subdomains/all_subdomains.txt")${NC}\n"

# --- 2. Filtragem de Hosts Ativos ---
echo -e "${BLUE}[2/6] Verificando hosts ativos com httpx...${NC}"
httpx -l "$OUTPUT_DIR/subdomains/all_subdomains.txt" -silent -o "$OUTPUT_DIR/subdomains/live_hosts.txt"
echo -e "${GREEN}[V] Hosts ativos encontrados: $(wc -l < "$OUTPUT_DIR/subdomains/live_hosts.txt")${NC}\n"

# --- 3. Varredura de Portas ---
echo -e "${BLUE}[3/6] Varrendo portas comuns com Naabu...${NC}"
naabu -l "$OUTPUT_DIR/subdomains/all_subdomains.txt" -top-ports 100 -silent -o "$OUTPUT_DIR/ports/naabu.txt"
echo -e "${GREEN}[V] Varredura de portas concluída.${NC}\n"

# --- 4. Identificação de Tech Stack ---
echo -e "${BLUE}[4/6] Identificando tecnologias com httpx...${NC}"
httpx -l "$OUTPUT_DIR/subdomains/live_hosts.txt" -td -title -status-code -silent -o "$OUTPUT_DIR/tech/tech_stack.txt"
echo -e "${GREEN}[V] Análise de tecnologias concluída.${NC}\n"

# --- 5. Varredura de Vulnerabilidades com Nuclei ---
echo -e "${BLUE}[5/6] Executando Nuclei (Templates Críticos/Altos)...${NC}"
nuclei -l "$OUTPUT_DIR/subdomains/live_hosts.txt" -severity critical,high -silent -o "$OUTPUT_DIR/nuclei/results.txt"
echo -e "${GREEN}[V] Varredura do Nuclei finalizada.${NC}\n"

# --- 6. Capturas de Tela ---
echo -e "${BLUE}[6/6] Tirando screenshots com Gowitness...${NC}"
gowitness file -f "$OUTPUT_DIR/subdomains/live_hosts.txt" --screenshot-path "$OUTPUT_DIR/screenshots/"
echo -e "${GREEN}[V] Capturas de tela concluídas.${NC}\n"

echo -e "${YELLOW}====================================================${NC}"
echo -e "${GREEN}Automação muuf concluída com sucesso!${NC}"
echo -e "${YELLOW}Confira os resultados em: $OUTPUT_DIR${NC}"
echo -e "${YELLOW}====================================================${NC}"
