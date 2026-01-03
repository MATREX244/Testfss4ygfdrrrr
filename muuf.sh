#!/bin/bash

# =============================================================================
# muuf - Ferramenta Profissional de Reconhecimento e Bug Hunting
# Desenvolvido por Manus AI para o Bug Bounty Hunter
# Versão: 1.0.0 - STABLE
# =============================================================================

# --- Variáveis Globais ---
VERSION="1.0.0"
CONFIG_FILE="config.ini"
LOG_FILE=""
DOMAIN=""
OUTPUT_DIR=""
VERBOSE=false
SILENT=false

# --- Variáveis de Contagem para Relatório ---
TOTAL_SUBDOMAINS=0
LIVE_HOSTS=0
JS_FILES=0
SECRETS=0
CRITICAL_VULNS=0
HIGH_VULNS=0
MEDIUM_VULNS=0

# --- Cores para o Terminal ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sem cor

# =============================================================================
# FUNÇÕES DE UTILIDADE
# =============================================================================

# Função de Logging
log() {
    local LEVEL=$1
    local MESSAGE=$2
    local TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Exibir no terminal
    case "$LEVEL" in
        "INFO")
            if [ "$SILENT" = false ]; then
                echo -e "${GREEN}[INFO]${NC} $MESSAGE"
            fi
            ;;
        "WARNING")
            if [ "$SILENT" = false ]; then
                echo -e "${YELLOW}[WARN]${NC} $MESSAGE"
            fi
            ;;
        "ERROR")
            echo -e "${RED}[ERRO]${NC} $MESSAGE" >&2
            ;;
        "DEBUG")
            if [ "$VERBOSE" = true ]; then
                echo -e "${BLUE}[DBUG]${NC} $MESSAGE"
            fi
            ;;
        *)
            echo "$MESSAGE"
            ;;
    esac
    
    # Salvar no arquivo de log
    if [ -n "$LOG_FILE" ]; then
        echo "[$TIMESTAMP] [$LEVEL] $MESSAGE" >> "$LOG_FILE"
    fi
}

# Função para ler valor do arquivo de configuração
get_config_value() {
    local SECTION=$1
    local KEY=$2
    # Usa awk para encontrar a seção e a chave, e extrair o valor
    awk -F'=' "/^\[$SECTION\]/{a=1;next}/^\\[/{a=0}a && \$1~/$KEY/{print \$2; exit}" "$CONFIG_FILE" | tr -d ' '
}

# Função de Verificação de Ferramentas
check_tool() {
    local TOOL_NAME=$1
    if ! command -v "$TOOL_NAME" &> /dev/null; then
        log "WARNING" "Ferramenta '$TOOL_NAME' não está instalada. Algumas funcionalidades estarão limitadas."
        return 1
    fi
    return 0
}

# Função para verificar ferramentas essenciais
check_essential_tools() {
    log "INFO" "Verificando ferramentas essenciais..."
    
    local ESSENTIAL_TOOLS=("curl" "jq" "httpx")
    local MISSING_ESSENTIAL=""
    
    for tool in "${ESSENTIAL_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            MISSING_ESSENTIAL="$MISSING_ESSENTIAL $tool"
        fi
    done
    
    if [ -n "$MISSING_ESSENTIAL" ]; then
        log "ERROR" "Ferramentas ESSENCIAIS faltando:$MISSING_ESSENTIAL"
        log "ERROR" "Execute './install.sh' para instalar as dependências."
        exit 1
    fi
    
    log "INFO" "Ferramentas essenciais verificadas com sucesso."
}

# Função para exibir o Banner
show_banner() {
    echo -e "${BLUE}"
    echo "  __  __ _    _ _    _ ______ "
    echo " |  \/  | |  | | |  | |  ____|"
    echo " | \  / | |  | | |  | | |__   "
    echo " | |\/| | |  | | |  | |  __|  "
    echo " | |  | | |__| | |__| | |     "
    echo " |_|  |_|\____/ \____/|_|     "
    echo -e "      Ferramenta de Automação Bug Hunter (muuf) v$VERSION${NC}\n"
}

# Função de Ajuda
show_help() {
    show_banner
    echo "Uso: $0 -d <dominio> [opções]"
    echo ""
    echo "Opções:"
    echo "  -d, --domain <dominio>    Domínio alvo (ex: exemplo.com)"
    echo "  -c, --config <arquivo>    Caminho para o arquivo de configuração (Padrão: $CONFIG_FILE)"
    echo "  -o, --output <diretorio>  Diretório de saída customizado"
    echo "  -v, --verbose             Modo Verbose (mais detalhes)"
    echo "  -s, --silent              Modo Silencioso (apenas erros)"
    echo "  -h, --help                Exibe esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0 -d example.com"
    echo "  $0 -d example.com -v"
    echo "  $0 -d example.com -c custom_config.ini"
    echo ""
    exit 0
}

# Função para tratar sinais (cleanup)
cleanup() {
    log "INFO" "Interrupção detectada. Realizando limpeza..."
    # Matar todos os processos em background
    jobs -p | xargs -r kill 2>/dev/null
    log "INFO" "Limpeza concluída. Saindo."
    exit 1
}

# =============================================================================
# FUNÇÕES DE MÓDULOS PRINCIPAIS
# =============================================================================

# Módulo 1: Reconhecimento (Subdomínios, IPs, Certificados)
module_reconnaissance() {
    log "INFO" "Iniciando Módulo de Reconhecimento..."
    
    local SUBDOMAINS_DIR="$OUTPUT_DIR/01_reconnaissance/subdomains"
    mkdir -p "$SUBDOMAINS_DIR"
    
    local ALL_SUBDOMAINS_FILE="$SUBDOMAINS_DIR/all_subdomains.txt"
    
    # 1.1 Descoberta de Subdomínios
    local TOOLS=$(get_config_value RECONNAISSANCE SUBDOMAIN_TOOLS | tr ',' ' ')
    
    for tool in $TOOLS; do
        if check_tool "$tool"; then
            log "INFO" "Executando $tool para descoberta de subdomínios..."
            local OUTPUT_FILE="$SUBDOMAINS_DIR/$tool.txt"
            case "$tool" in
                "subfinder")
                    subfinder -d "$DOMAIN" -o "$OUTPUT_FILE" -silent 2>/dev/null
                    ;;
                "amass")
                    amass enum -passive -d "$DOMAIN" -o "$OUTPUT_FILE" 2>/dev/null
                    ;;
                "assetfinder")
                    assetfinder --subs-only "$DOMAIN" > "$OUTPUT_FILE" 2>/dev/null
                    ;;
                "crtsh")
                    # Uso de crt.sh via curl/API com tratamento de erro
                    if curl -s "https://crt.sh/?q=%25.$DOMAIN&output=json" 2>/dev/null | jq -r '.[].name_value' 2>/dev/null | sed 's/\*\.//g' | sort -u > "$OUTPUT_FILE"; then
                        log "DEBUG" "crt.sh executado com sucesso"
                    else
                        log "WARNING" "Falha ao executar crt.sh (API pode estar indisponível)"
                        touch "$OUTPUT_FILE"
                    fi
                    ;;
                *)
                    log "WARNING" "Ferramenta de subdomínio '$tool' não suportada."
                    ;;
            esac
        fi
    done
    
    # 1.2 Consolidação e Filtragem
    log "INFO" "Consolidando e filtrando subdomínios únicos..."
    cat "$SUBDOMAINS_DIR/"*.txt 2>/dev/null | grep -E "\.$DOMAIN$" | sort -u > "$ALL_SUBDOMAINS_FILE"
    TOTAL_SUBDOMAINS=$(wc -l < "$ALL_SUBDOMAINS_FILE" 2>/dev/null || echo 0)
    log "INFO" "Total de subdomínios únicos encontrados: $TOTAL_SUBDOMAINS"
    
    # 1.3 Filtragem de Hosts Ativos
    local LIVE_HOSTS_FILE="$SUBDOMAINS_DIR/live_hosts.txt"
    if [ -s "$ALL_SUBDOMAINS_FILE" ]; then
        log "INFO" "Verificando hosts ativos com httpx..."
        httpx -l "$ALL_SUBDOMAINS_FILE" -silent -o "$LIVE_HOSTS_FILE" -threads $(get_config_value GLOBAL MAX_PARALLEL_PROCESSES) 2>/dev/null
        LIVE_HOSTS=$(wc -l < "$LIVE_HOSTS_FILE" 2>/dev/null || echo 0)
        log "INFO" "Hosts ativos encontrados: $LIVE_HOSTS"
    else
        log "WARNING" "Nenhum subdomínio encontrado. Pulando verificação de hosts ativos."
    fi
    
    log "INFO" "Módulo de Reconhecimento concluído."
}

# Módulo 2: Varredura (Portas, Serviços, Tecnologias)
module_scanning() {
    log "INFO" "Iniciando Módulo de Varredura..."
    
    local SCANNING_DIR="$OUTPUT_DIR/02_scanning"
    mkdir -p "$SCANNING_DIR"/{ports,technologies}
    
    local LIVE_HOSTS_FILE="$OUTPUT_DIR/01_reconnaissance/subdomains/live_hosts.txt"
    
    if [ ! -s "$LIVE_HOSTS_FILE" ]; then
        log "WARNING" "Nenhum host ativo encontrado. Pulando Módulo de Varredura."
        return
    fi
    
    # 2.1 Varredura de Portas com Naabu
    if check_tool "naabu"; then
        log "INFO" "Varrendo portas com Naabu..."
        local NAABU_PORTS=$(get_config_value SCANNING NAABU_PORTS)
        naabu -l "$LIVE_HOSTS_FILE" -p "$NAABU_PORTS" -silent -o "$SCANNING_DIR/ports/naabu.txt" -rate 1000 2>/dev/null
        log "INFO" "Varredura de portas concluída. Resultados em $SCANNING_DIR/ports/naabu.txt"
    fi
    
    # 2.2 Identificação de Tech Stack com httpx
    if check_tool "httpx"; then
        log "INFO" "Identificando tecnologias com httpx..."
        httpx -l "$LIVE_HOSTS_FILE" -td -title -status-code -silent -o "$SCANNING_DIR/technologies/tech_stack.txt" -json -threads $(get_config_value GLOBAL MAX_PARALLEL_PROCESSES) 2>/dev/null
        log "INFO" "Análise de tecnologias concluída. Resultados em $SCANNING_DIR/technologies/tech_stack.txt"
    fi
    
    # 2.3 Fingerprinting Avançado com WhatWeb
    if check_tool "whatweb"; then
        log "INFO" "Fingerprinting avançado com WhatWeb..."
        local MAX_PARALLEL=$(get_config_value GLOBAL MAX_PARALLEL_PROCESSES)
        local WHATWEB_OUTPUT="$SCANNING_DIR/technologies/whatweb.txt"
        
        # Limpar o arquivo de saída antes de iniciar
        > "$WHATWEB_OUTPUT"
        
        while IFS= read -r host; do
            whatweb "$host" -v 2>/dev/null >> "$WHATWEB_OUTPUT" &
            # Controle de paralelismo
            if (( $(jobs -r | wc -l) >= MAX_PARALLEL )); then
                wait -n
            fi
        done < "$LIVE_HOSTS_FILE"
        
        # Esperar todos os processos em background terminarem
        wait
        
        log "INFO" "Fingerprinting WhatWeb concluído. Resultados em $WHATWEB_OUTPUT"
    fi
    
    log "INFO" "Módulo de Varredura concluído."
}

# Módulo 3: Análise Web (Crawling, JS, Parâmetros)
module_web_analysis() {
    log "INFO" "Iniciando Módulo de Análise Web..."
    
    local WEB_DIR="$OUTPUT_DIR/03_web_analysis"
    mkdir -p "$WEB_DIR"/{crawling,endpoints,js_analysis}
    
    local LIVE_HOSTS_FILE="$OUTPUT_DIR/01_reconnaissance/subdomains/live_hosts.txt"
    
    if [ ! -s "$LIVE_HOSTS_FILE" ]; then
        log "WARNING" "Nenhum host ativo encontrado. Pulando Módulo de Análise Web."
        return
    fi
    
    # 3.1 Crawling Inteligente com Katana
    if check_tool "katana"; then
        log "INFO" "Realizando crawling inteligente com Katana..."
        katana -list "$LIVE_HOSTS_FILE" -silent -o "$WEB_DIR/crawling/katana_urls.txt" -jc -jsl -d 3 -c $(get_config_value GLOBAL MAX_PARALLEL_PROCESSES) 2>/dev/null
        
        # Extrair parâmetros e endpoints
        if [ -s "$WEB_DIR/crawling/katana_urls.txt" ]; then
            grep '?' "$WEB_DIR/crawling/katana_urls.txt" 2>/dev/null | sort -u > "$WEB_DIR/endpoints/parameters.txt" || touch "$WEB_DIR/endpoints/parameters.txt"
            grep -E '/api/|/v[0-9]/' "$WEB_DIR/crawling/katana_urls.txt" 2>/dev/null | sort -u > "$WEB_DIR/endpoints/api_endpoints.txt" || touch "$WEB_DIR/endpoints/api_endpoints.txt"
        fi
        
        log "INFO" "Crawling concluído. URLs em "$WEB_DIR/crawling/katana_urls.txt""
    fi
    
    log "INFO" "Módulo de Análise Web concluído."
}

# Módulo 3.5: Análise de JavaScript
module_js_analysis() {
    log "INFO" "Iniciando Módulo de Análise de JavaScript..."
    
    local JS_DIR="$OUTPUT_DIR/03_web_analysis/js_analysis"
    mkdir -p "$JS_DIR"
    
    local URLS_FILE="$OUTPUT_DIR/03_web_analysis/crawling/katana_urls.txt"
    
    if [ ! -s "$URLS_FILE" ]; then
        log "WARNING" "Nenhuma URL encontrada pelo Katana. Pulando Análise de JS."
        return
    fi
    
    # 3.5.1 Extração de URLs de JS
    grep -E '\.js(\?|$)' "$URLS_FILE" 2>/dev/null | sort -u > "$JS_DIR/js_urls.txt"
    
    if [ ! -s "$JS_DIR/js_urls.txt" ]; then
        log "INFO" "Nenhum arquivo JavaScript encontrado."
        return
    fi
    
    local TOTAL_JS=$(wc -l < "$JS_DIR/js_urls.txt")
    log "INFO" "Encontrados $TOTAL_JS arquivos JavaScript. Analisando os primeiros 50..."
    
    # Baixar e analisar arquivos JS (limitado a 50)
    head -n 50 "$JS_DIR/js_urls.txt" | while read -r JS_URL; do
        local FILENAME=$(echo "$JS_URL" | sed -E 's/https?:\/\///' | tr -c '[:alnum:]\n' '_' | cut -c 1-50)
        local LOCAL_PATH="$JS_DIR/$FILENAME.js"
        
        log "DEBUG" "Baixando $JS_URL"
        curl -sk "$JS_URL" -o "$LOCAL_PATH" 2>/dev/null
        
        if [ -s "$LOCAL_PATH" ]; then
            JS_FILES=$((JS_FILES + 1))
            
            # Busca por secrets (API Keys, Tokens, etc.)
            local SECRETS_FOUND=$(grep -iE 'api[_-]?key|token|secret|password|aws|access[_-]?key' "$LOCAL_PATH" 2>/dev/null | wc -l)
            if [ "$SECRETS_FOUND" -gt 0 ]; then
                SECRETS=$((SECRETS + SECRETS_FOUND))
                echo "$JS_URL" >> "$JS_DIR/files_with_secrets.txt"
                log "WARNING" "Potenciais secrets encontrados em $JS_URL"
            fi
            
            # Busca por endpoints
            grep -oE '(\/[a-zA-Z0-9_-]+\/[a-zA-Z0-9_-]+|/api/[^"'\''[:space:]]+)' "$LOCAL_PATH" 2>/dev/null | sort -u >> "$JS_DIR/endpoints_from_js.txt"
        fi
    done
    
    # Remover duplicatas de endpoints
    if [ -f "$JS_DIR/endpoints_from_js.txt" ]; then
        sort -u "$JS_DIR/endpoints_from_js.txt" -o "$JS_DIR/endpoints_from_js.txt"
    fi
    
    log "INFO" "Módulo de Análise de JavaScript concluído. Arquivos analisados: $JS_FILES, Potenciais secrets: $SECRETS"
}

# Módulo 4: Varredura de Vulnerabilidades
module_vulnerability_scan() {
    log "INFO" "Iniciando Módulo de Varredura de Vulnerabilidades..."
    
    local VULN_DIR="$OUTPUT_DIR/04_vulnerabilities"
    mkdir -p "$VULN_DIR"/{nuclei,fuzzing,custom_tests}
    
    local LIVE_HOSTS_FILE="$OUTPUT_DIR/01_reconnaissance/subdomains/live_hosts.txt"
    
    if [ ! -s "$LIVE_HOSTS_FILE" ]; then
        log "WARNING" "Nenhum host ativo encontrado. Pulando Módulo de Vulnerabilidades."
        return
    fi
    
    # 4.1 Varredura com Nuclei
    if check_tool "nuclei"; then
        local SEVERITIES=$(get_config_value VULNERABILITY NUCLEI_SEVERITIES)
        log "INFO" "Executando Nuclei para severidades: $SEVERITIES..."
        nuclei -l "$LIVE_HOSTS_FILE" -severity "$SEVERITIES" -silent -o "$VULN_DIR/nuclei/results.json" -json 2>/dev/null
        log "INFO" "Varredura do Nuclei finalizada. Resultados em $VULN_DIR/nuclei/results.json"
        
        # Contagem de vulnerabilidades
        if [ -s "$VULN_DIR/nuclei/results.json" ]; then
            CRITICAL_VULNS=$(grep -c '"severity":"critical"' "$VULN_DIR/nuclei/results.json" 2>/dev/null || echo 0)
            HIGH_VULNS=$(grep -c '"severity":"high"' "$VULN_DIR/nuclei/results.json" 2>/dev/null || echo 0)
            MEDIUM_VULNS=$(grep -c '"severity":"medium"' "$VULN_DIR/nuclei/results.json" 2>/dev/null || echo 0)
        fi
    fi
    
    # 4.2 Fuzzing de Diretórios com ffuf
    if [ "$(get_config_value VULNERABILITY FUZZ_DIRECTORIES)" = "true" ] && check_tool "ffuf"; then
        log "INFO" "Iniciando fuzzing de diretórios com ffuf..."
        local WORDLIST=$(get_config_value VULNERABILITY FUZZ_WORDLIST)
        
        if [ ! -f "$WORDLIST" ]; then
            log "WARNING" "Wordlist '$WORDLIST' não encontrada. Pulando fuzzing."
        else
            while IFS= read -r host; do
                local SAFE_NAME=$(echo "$host" | sed 's|https\?://||g' | tr ':/' '_')
                log "DEBUG" "Fuzzing em $host..."
                ffuf -w "$WORDLIST" -u "$host/FUZZ" -mc 200,201,202,203,301,302,307,401,403,405,500 -o "$VULN_DIR/fuzzing/ffuf_${SAFE_NAME}.json" -of json -s 2>/dev/null &
                
                # Controle de paralelismo
                if (( $(jobs -r | wc -l) >= $(get_config_value GLOBAL MAX_PARALLEL_PROCESSES) )); then
                    wait -n
                fi
            done < "$LIVE_HOSTS_FILE"
            wait
            log "INFO" "Fuzzing de diretórios concluído."
        fi
    fi
    
    # 4.3 Teste de Subdomain Takeover com Subjack
    if [ "$(get_config_value VULNERABILITY SUBDOMAIN_TAKEOVER)" = "true" ] && check_tool "subjack"; then
        log "INFO" "Testando Subdomain Takeover com Subjack..."
        subjack -w "$LIVE_HOSTS_FILE" -t $(get_config_value GLOBAL MAX_PARALLEL_PROCESSES) -timeout 30 -o "$VULN_DIR/custom_tests/subjack_results.txt" -ssl 2>/dev/null
        log "INFO" "Teste de Subdomain Takeover concluído. Resultados em $VULN_DIR/custom_tests/subjack_results.txt"
    fi
    
    log "INFO" "Módulo de Varredura de Vulnerabilidades concluído."
}

# Módulo 4.5: Testes Específicos
module_specific_tests() {
    log "INFO" "Iniciando Módulo de Testes Específicos..."
    
    local VULN_DIR="$OUTPUT_DIR/04_vulnerabilities"
    mkdir -p "$VULN_DIR/custom_tests"
    local LIVE_HOSTS_FILE="$OUTPUT_DIR/01_reconnaissance/subdomains/live_hosts.txt"
    
    if [ ! -s "$LIVE_HOSTS_FILE" ]; then
        log "WARNING" "Nenhum host ativo encontrado. Pulando Testes Específicos."
        return
    fi
    
    # 4.4 Teste de CORS Misconfiguration
    if [ "$(get_config_value VULNERABILITY CORS_MISCONFIGURATION)" = "true" ]; then
        if check_tool "nuclei"; then
            log "INFO" "Testando CORS Misconfiguration com Nuclei..."
            nuclei -l "$LIVE_HOSTS_FILE" -t "misconfiguration/cors-*" -silent -o "$VULN_DIR/custom_tests/cors_results.txt" 2>/dev/null
            log "INFO" "Teste de CORS concluído. Resultados em $VULN_DIR/custom_tests/cors_results.txt"
        else
            log "INFO" "Testando CORS Misconfiguration manualmente..."
            > "$VULN_DIR/custom_tests/cors_manual.txt"
            while IFS= read -r url; do
                response=$(curl -sk -H "Origin: https://evil.com" -I "$url" 2>/dev/null)
                if echo "$response" | grep -qi "access-control-allow-origin.*evil.com"; then
                    echo "$url" >> "$VULN_DIR/custom_tests/cors_manual.txt"
                    log "WARNING" "CORS vulnerável: $url"
                fi
            done < "$LIVE_HOSTS_FILE"
        fi
    fi
    
    # 4.5 Teste de Open Redirect
    if [ "$(get_config_value VULNERABILITY OPEN_REDIRECT)" = "true" ] && check_tool "nuclei"; then
        log "INFO" "Testando Open Redirect com Nuclei..."
        nuclei -l "$LIVE_HOSTS_FILE" -t "vulnerabilities/generic/open-redirect*" -silent -o "$VULN_DIR/custom_tests/open_redirect_results.txt" 2>/dev/null
        log "INFO" "Teste de Open Redirect concluído. Resultados em $VULN_DIR/custom_tests/open_redirect_results.txt"
    fi
    
    log "INFO" "Módulo de Testes Específicos concluído."
}

# Módulo 5: Visual (Screenshots)
module_visual() {
    log "INFO" "Iniciando Módulo Visual (Screenshots)..."
    
    local VISUAL_DIR="$OUTPUT_DIR/05_visual/screenshots"
    mkdir -p "$VISUAL_DIR"
    
    local LIVE_HOSTS_FILE="$OUTPUT_DIR/01_reconnaissance/subdomains/live_hosts.txt"
    
    if [ ! -s "$LIVE_HOSTS_FILE" ]; then
        log "WARNING" "Nenhum host ativo encontrado. Pulando Módulo Visual."
        return
    fi
    
    # 5.1 Capturas de Tela com Gowitness
    if check_tool "gowitness"; then
        log "INFO" "Tirando screenshots com Gowitness..."
        gowitness file -f "$LIVE_HOSTS_FILE" --screenshot-path "$VISUAL_DIR/" 2>/dev/null
        log "INFO" "Capturas de tela concluídas. Imagens em $VISUAL_DIR"
    fi
    
    log "INFO" "Módulo Visual concluído."
}

# Módulo 6: Relatórios e Output
module_reporting() {
    log "INFO" "Iniciando Módulo de Relatórios..."
    
    local REPORTS_DIR="$OUTPUT_DIR/reports"
    mkdir -p "$REPORTS_DIR"
    
    # 6.1 Geração de Relatório Markdown
    log "INFO" "Gerando relatório Markdown de resumo..."
    {
        echo "# Relatório de Reconhecimento muuf - $DOMAIN"
        echo ""
        echo "## Sumário Executivo"
        echo "Data do Scan: $(date)"
        echo "Domínio Alvo: $DOMAIN"
        echo "Diretório de Saída: $OUTPUT_DIR"
        echo ""
        echo "## Estatísticas"
        echo "Total de Subdomínios Encontrados: $TOTAL_SUBDOMAINS"
        echo "Hosts Ativos: $LIVE_HOSTS"
        echo "Arquivos JS Analisados: $JS_FILES"
        echo "Potenciais Secrets em JS: $SECRETS"
        echo ""
        echo "## Resultados de Vulnerabilidades (Nuclei)"
        echo "\`\`\`"
        echo "Críticas: $CRITICAL_VULNS"
        echo "Altas: $HIGH_VULNS"
        echo "Médias: $MEDIUM_VULNS"
        echo "\`\`\`"
        echo ""
        echo "## Próximos Passos"
        echo "Verifique os arquivos detalhados em cada subdiretório para análise aprofundada."
        
    } > "$REPORTS_DIR/summary.md"
    
    log "INFO" "Relatório Markdown gerado em $REPORTS_DIR/summary.md"
    
    # 6.2 Geração de Relatório JSON
    if [ "$(get_config_value REPORTING GENERATE_JSON)" = "true" ]; then
        log "INFO" "Gerando relatório JSON..."
        
        cat > "$REPORTS_DIR/summary.json" << EOF
{
  "scan_info": {
    "domain": "$DOMAIN",
    "date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "muuf_version": "$VERSION",
    "output_directory": "$OUTPUT_DIR"
  },
  "statistics": {
    "total_subdomains": $TOTAL_SUBDOMAINS,
    "live_hosts": $LIVE_HOSTS,
    "javascript_files": $JS_FILES,
    "potential_secrets": $SECRETS
  },
  "vulnerabilities": {
    "critical": $CRITICAL_VULNS,
    "high": $HIGH_VULNS,
    "medium": $MEDIUM_VULNS,
    "total": $((CRITICAL_VULNS + HIGH_VULNS + MEDIUM_VULNS))
  },
  "files": {
    "subdomains": "$OUTPUT_DIR/01_reconnaissance/subdomains/all_subdomains.txt",
    "live_hosts": "$OUTPUT_DIR/01_reconnaissance/subdomains/live_hosts.txt",
    "nuclei_results": "$OUTPUT_DIR/04_vulnerabilities/nuclei/results.json",
    "js_analysis_dir": "$OUTPUT_DIR/03_web_analysis/js_analysis/",
    "screenshots_dir": "$OUTPUT_DIR/05_visual/screenshots/"
  }
}
EOF
        log "INFO" "Relatório JSON gerado em $REPORTS_DIR/summary.json"
    fi
    
    # 6.3 Copiar timeline de log
    if [ -f "$LOG_FILE" ]; then
        cp "$LOG_FILE" "$REPORTS_DIR/timeline.log"
    fi
    
    log "INFO" "Módulo de Relatórios concluído."
}

# =============================================================================
# LÓGICA PRINCIPAL
# =============================================================================

# Captura de sinais para limpeza
trap cleanup SIGINT SIGTERM

# 1. Processar Argumentos de Linha de Comando
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -d|--domain)
            DOMAIN="$2"
            shift
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            ;;
        -s|--silent)
            SILENT=true
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log "ERROR" "Argumento desconhecido: $1"
            show_help
            ;;
    esac
    shift
done

# 2. Validação de Input
if [ -z "$DOMAIN" ]; then
    show_banner
    log "ERROR" "Domínio alvo não especificado. Use -d ou --domain."
    echo ""
    log "INFO" "Execute '$0 --help' para ver as opções disponíveis."
    exit 1
fi

# 3. Configuração Inicial
if [ ! -f "$CONFIG_FILE" ]; then
    log "ERROR" "Arquivo de configuração '$CONFIG_FILE' não encontrado."
    log "INFO" "Crie o arquivo config.ini ou especifique um caminho com -c"
    exit 1
fi

if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_BASE_DIR=$(get_config_value GLOBAL OUTPUT_BASE_DIR)
    if [ -z "$OUTPUT_BASE_DIR" ]; then
        OUTPUT_BASE_DIR="./results"
    fi
    DATE=$(date +%Y%m%d_%H%M%S)
    OUTPUT_DIR="$OUTPUT_BASE_DIR/${DOMAIN}_${DATE}"
fi

mkdir -p "$OUTPUT_DIR"
LOG_FILE="$OUTPUT_DIR/muuf_timeline.log"

show_banner
log "INFO" "Iniciando automação para: $DOMAIN"
log "INFO" "Resultados serão salvos em: $OUTPUT_DIR"
log "INFO" "===================================================="

# 4. Verificação de Dependências
check_essential_tools

# 5. Execução dos Módulos
START_TIME=$(date +%s)

module_reconnaissance
module_scanning
module_web_analysis
module_js_analysis
module_vulnerability_scan
module_specific_tests
module_visual
module_reporting

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_MIN=$((DURATION / 60))
DURATION_SEC=$((DURATION % 60))

# 6. Finalização
echo ""
log "INFO" "===================================================="
log "INFO" "🎉 Automação muuf concluída com sucesso!"
log "INFO" "⏱️  Tempo total de execução: ${DURATION_MIN}m ${DURATION_SEC}s"
log "INFO" "📂 Confira os resultados em: $OUTPUT_DIR"
log "INFO" "📊 Relatório resumido: $OUTPUT_DIR/reports/summary.md"
log "INFO" "===================================================="
echo ""

# Exibir resumo final
if [ "$SILENT" = false ]; then
    echo -e "${BLUE}📊 Resumo Final:${NC}"
    echo -e "   Subdomínios: ${GREEN}$TOTAL_SUBDOMAINS${NC}"
    echo -e "   Hosts Ativos: ${GREEN}$LIVE_HOSTS${NC}"
    echo -e "   Vulnerabilidades Críticas: ${RED}$CRITICAL_VULNS${NC}"
    echo -e "   Vulnerabilidades Altas: ${YELLOW}$HIGH_VULNS${NC}"
    echo ""
fi

exit 0
