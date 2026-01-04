#!/bin/bash

# =============================================================================
# muuf PRO v2.1 - Ultimate Bug Bounty Automation Framework
# Refactored for Stability, Performance, and Elite Methodology
# =============================================================================

# --- Colors & UI ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Global Settings ---
VERSION="2.1.0-ELITE"
DOMAIN=""
OUTPUT_DIR=""
THREADS=50
TIMEOUT=30
SILENT=false
DEBUG=false

# --- Banner ---
show_banner() {
    echo -e "${CYAN}"
    echo "███╗   ███╗██╗   ██╗██╗   ██╗███████╗    ██████╗ ██████╗  ██████╗ "
    echo "████╗ ████║██║   ██║██║   ██║██╔════╝    ██╔══██╗██╔══██╗██╔═══██╗"
    echo "██╔████╔██║██║   ██║██║   ██║█████╗      ██████╔╝██████╔╝██║   ██║"
    echo "██║╚██╔╝██║██║   ██║██║   ██║██╔══╝      ██╔═══╝ ██╔══██╗██║   ██║"
    echo "██║ ╚═╝ ██║╚██████╔╝╚██████╔╝██║         ██║     ██║  ██║╚██████╔╝"
    echo "╚═╝     ╚═╝ ╚═════╝  ╚═════╝ ╚═╝         ╚═╝     ╚═╝  ╚═╝ ╚═════╝ "
    echo -e "      ${PURPLE}Elite Bug Bounty Automation Framework v$VERSION${NC}\n"
}

# --- Enhanced Logging ---
log() {
    local LEVEL=$1
    local MSG=$2
    local TIMESTAMP=$(date +"%H:%M:%S")
    case "$LEVEL" in
        "INFO") echo -e "${BLUE}[$TIMESTAMP]${NC} ${GREEN}[+]${NC} $MSG" ;;
        "WARN") echo -e "${BLUE}[$TIMESTAMP]${NC} ${YELLOW}[!]${NC} $MSG" ;;
        "ERR")  echo -e "${BLUE}[$TIMESTAMP]${NC} ${RED}[-]${NC} $MSG" ;;
        "ACT")  echo -e "${BLUE}[$TIMESTAMP]${NC} ${PURPLE}[*]${NC} $MSG" ;;
    esac
}

# --- Error Handling & Cleanup ---
cleanup() {
    log "WARN" "Interrupted! Cleaning up temporary files..."
    exit 1
}
trap cleanup SIGINT SIGTERM

# --- Dependency Check ---
check_deps() {
    log "ACT" "Checking dependencies..."
    local missing_deps=()
    local deps=("subfinder" "amass" "httpx" "nuclei" "katana" "gau" "ffuf" "anew" "notify" "assetfinder")
    
    # Adicionar o caminho do Go ao PATH atual para garantir que as ferramentas sejam encontradas
    export PATH=$PATH:$HOME/go/bin:/usr/local/go/bin
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log "ERR" "The following tools are missing: ${missing_deps[*]}"
        log "WARN" "Please run './install.sh' to install all dependencies."
        exit 1
    else
        log "INFO" "All dependencies are satisfied."
    fi
}

# --- Directory Setup ---
setup_dirs() {
    [[ -z "$DOMAIN" ]] && { log "ERR" "Domain is required. Use -d domain.com"; exit 1; }
    
    if [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR="results/$DOMAIN-$(date +%Y%m%d_%H%M%S)"
    fi
    
    mkdir -p "$OUTPUT_DIR"/{recon,probing,endpoints,vulns,js_analysis,fuzzing}
    log "INFO" "Workspace initialized: $OUTPUT_DIR"
}

# --- 1. Reconnaissance ---
run_recon() {
    log "ACT" "Phase 1: Subdomain Enumeration"
    
    log "INFO" "Running Subfinder..."
    subfinder -d "$DOMAIN" -all -silent -o "$OUTPUT_DIR/recon/subfinder.txt" &>/dev/null
    
    log "INFO" "Running Assetfinder..."
    assetfinder --subs-only "$DOMAIN" | anew "$OUTPUT_DIR/recon/assetfinder.txt" &>/dev/null
    
    if command -v amass &> /dev/null; then
        log "INFO" "Running Amass (Passive)..."
        amass enum -passive -d "$DOMAIN" -silent -o "$OUTPUT_DIR/recon/amass.txt" &>/dev/null
    fi
    
    log "INFO" "Fetching from crt.sh..."
    curl -s "https://crt.sh/?q=%25.$DOMAIN&output=json" | jq -r '.[].name_value' 2>/dev/null | sed 's/\*\.//g' | sort -u | anew "$OUTPUT_DIR/recon/crtsh.txt" &>/dev/null

    cat "$OUTPUT_DIR/recon/"*.txt | sort -u | anew "$OUTPUT_DIR/recon/all_subdomains.txt" > /dev/null
    local total=$(wc -l < "$OUTPUT_DIR/recon/all_subdomains.txt")
    log "INFO" "Total unique subdomains found: $total"
}

# --- 2. Probing ---
run_probing() {
    log "ACT" "Phase 2: Probing for Live Hosts"
    
    if [[ ! -s "$OUTPUT_DIR/recon/all_subdomains.txt" ]]; then
        log "ERR" "No subdomains found to probe."
        return
    fi

    cat "$OUTPUT_DIR/recon/all_subdomains.txt" | httpx \
        -threads "$THREADS" \
        -timeout "$TIMEOUT" \
        -silent \
        -title -tech-detect -status-code \
        -follow-redirects \
        -o "$OUTPUT_DIR/probing/httpx_full.txt" &>/dev/null

    cat "$OUTPUT_DIR/probing/httpx_full.txt" | awk '{print $1}' | anew "$OUTPUT_DIR/probing/live_urls.txt" > /dev/null
    
    local live_count=$(wc -l < "$OUTPUT_DIR/probing/live_urls.txt")
    log "INFO" "Live hosts identified: $live_count"
}

# --- 3. Endpoint Discovery ---
run_endpoints() {
    log "ACT" "Phase 3: Deep Endpoint Discovery"
    
    if [[ ! -s "$OUTPUT_DIR/probing/live_urls.txt" ]]; then
        log "ERR" "No live hosts to crawl."
        return
    fi

    log "INFO" "Fetching history from Gau..."
    cat "$OUTPUT_DIR/recon/all_subdomains.txt" | gau --subs --threads 10 | anew "$OUTPUT_DIR/endpoints/gau.txt" &>/dev/null
    
    log "INFO" "Crawling with Katana..."
    katana -list "$OUTPUT_DIR/probing/live_urls.txt" -silent -nc -jc -kf all -d 3 -o "$OUTPUT_DIR/endpoints/katana.txt" &>/dev/null
    
    cat "$OUTPUT_DIR/endpoints/"*.txt | sort -u | anew "$OUTPUT_DIR/endpoints/all_urls.txt" > /dev/null
    
    grep -E "\.js(\?|$)" "$OUTPUT_DIR/endpoints/all_urls.txt" | anew "$OUTPUT_DIR/endpoints/js_files.txt" > /dev/null
    grep "=" "$OUTPUT_DIR/endpoints/all_urls.txt" | anew "$OUTPUT_DIR/endpoints/params.txt" > /dev/null
    
    log "INFO" "Total endpoints: $(wc -l < "$OUTPUT_DIR/endpoints/all_urls.txt")"
}

# --- 4. Vulnerability Scanning ---
run_vulns() {
    log "ACT" "Phase 4: Vulnerability Scanning"
    
    if [[ ! -s "$OUTPUT_DIR/probing/live_urls.txt" ]]; then
        return
    fi

    log "INFO" "Running Nuclei (Critical/High/Medium)..."
    nuclei -l "$OUTPUT_DIR/probing/live_urls.txt" \
        -severity critical,high,medium \
        -silent -o "$OUTPUT_DIR/vulns/nuclei_results.txt"

    if [[ -s "$OUTPUT_DIR/vulns/nuclei_results.txt" ]] && command -v notify &> /dev/null; then
        cat "$OUTPUT_DIR/vulns/nuclei_results.txt" | notify -silent
    fi
}

# --- 5. Advanced Fuzzing ---
run_fuzzing() {
    log "ACT" "Phase 5: Advanced Fuzzing & Bypasses"
    
    grep "403" "$OUTPUT_DIR/probing/httpx_full.txt" | awk '{print $1}' > "$OUTPUT_DIR/fuzzing/403_targets.txt"
    
    if [[ -s "$OUTPUT_DIR/fuzzing/403_targets.txt" ]]; then
        local wordlist="./wordlists/403_bypass.txt"
        if [[ -f "$wordlist" ]]; then
            while read -r target; do
                log "INFO" "Testing bypass on: $target"
                ffuf -u "$target/FUZZ" -w "$wordlist" -mc 200,206 -silent -o "$OUTPUT_DIR/fuzzing/ffuf_403_$(date +%s).json" &>/dev/null
            done < "$OUTPUT_DIR/fuzzing/403_targets.txt"
        fi
    fi
}

# --- Main Execution ---
main() {
    show_banner
    
    while getopts "d:t:o:h" opt; do
        case $opt in
            d) DOMAIN=$OPTARG ;;
            t) THREADS=$OPTARG ;;
            o) OUTPUT_DIR=$OPTARG ;;
            h) echo "Usage: $0 -d domain.com [-t threads] [-o output_dir]"; exit 0 ;;
            *) exit 1 ;;
        esac
    done

    check_deps
    setup_dirs
    
    run_recon
    run_probing
    run_endpoints
    run_vulns
    run_fuzzing
    
    log "INFO" "Scan completed for $DOMAIN"
    log "ACT" "Results saved in: $OUTPUT_DIR"
}

main "$@"
