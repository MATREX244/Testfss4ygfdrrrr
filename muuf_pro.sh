#!/bin/bash

# =============================================================================
# muuf PRO - Advanced Bug Bounty Automation Framework
# Inspired by 6-figure hunters methodology
# Version: 2.0.0-PRO
# =============================================================================

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Global Variables ---
VERSION="2.0.0-PRO"
DOMAIN=""
OUTPUT_DIR=""
THREADS=50
SILENT=false

# --- Banner ---
show_banner() {
    echo -e "${CYAN}"
    echo "███╗   ███╗██╗   ██╗██╗   ██╗███████╗    ██████╗ ██████╗  ██████╗ "
    echo "████╗ ████║██║   ██║██║   ██║██╔════╝    ██╔══██╗██╔══██╗██╔═══██╗"
    echo "██╔████╔██║██║   ██║██║   ██║█████╗      ██████╔╝██████╔╝██║   ██║"
    echo "██║╚██╔╝██║██║   ██║██║   ██║██╔══╝      ██╔═══╝ ██╔══██╗██║   ██║"
    echo "██║ ╚═╝ ██║╚██████╔╝╚██████╔╝██║         ██║     ██║  ██║╚██████╔╝"
    echo "╚═╝     ╚═╝ ╚═════╝  ╚═════╝ ╚═╝         ╚═╝     ╚═╝  ╚═╝ ╚═════╝ "
    echo -e "      Advanced Bug Bounty Automation Framework v$VERSION${NC}\n"
}

# --- Logging ---
log() {
    local LEVEL=$1
    local MSG=$2
    case "$LEVEL" in
        "INFO") echo -e "${GREEN}[+]${NC} $MSG" ;;
        "WARN") echo -e "${YELLOW}[!]${NC} $MSG" ;;
        "ERR")  echo -e "${RED}[-]${NC} $MSG" ;;
        "ACT")  echo -e "${PURPLE}[*]${NC} $MSG" ;;
    esac
}

# --- Dependency Check ---
check_deps() {
    local deps=("subfinder" "amass" "httpx" "nuclei" "katana" "gau" "ffuf" "naabu" "anew" "notify")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log "WARN" "Dependency '$dep' not found. Some features may be disabled."
        fi
    done
}

# --- Main Modules ---

# 1. Passive & Active Recon
recon() {
    log "ACT" "Starting Reconnaissance for $DOMAIN"
    mkdir -p "$OUTPUT_DIR/recon"
    
    # Subdomain Enumeration
    log "INFO" "Running Subfinder..."
    subfinder -d "$DOMAIN" -silent -all -o "$OUTPUT_DIR/recon/subfinder.txt"
    
    log "INFO" "Running Assetfinder..."
    assetfinder --subs-only "$DOMAIN" | anew "$OUTPUT_DIR/recon/assetfinder.txt"
    
    # Passive Amass (Only if installed)
    if command -v amass &> /dev/null; then
        log "INFO" "Running Amass Passive..."
        amass enum -passive -d "$DOMAIN" -silent -o "$OUTPUT_DIR/recon/amass.txt"
    fi

    # Merge and Sort
    cat "$OUTPUT_DIR/recon/"*.txt | sort -u | anew "$OUTPUT_DIR/recon/all_subdomains.txt"
    log "INFO" "Total unique subdomains: $(wc -l < "$OUTPUT_DIR/recon/all_subdomains.txt")"
}

# 2. Probing & Port Scanning
probing() {
    log "ACT" "Probing for live hosts..."
    mkdir -p "$OUTPUT_DIR/probing"
    
    cat "$OUTPUT_DIR/recon/all_subdomains.txt" | httpx -silent -threads "$THREADS" -title -tech-detect -status-code -follow-redirects -o "$OUTPUT_DIR/probing/live.txt"
    
    # Extract only URLs for next tools
    cat "$OUTPUT_DIR/probing/live.txt" | awk '{print $1}' | anew "$OUTPUT_DIR/probing/urls.txt"
    log "INFO" "Live hosts found: $(wc -l < "$OUTPUT_DIR/probing/urls.txt")"
}

# 3. Endpoint Discovery (The "Gold Mine")
endpoints() {
    log "ACT" "Discovering Endpoints & Parameters..."
    mkdir -p "$OUTPUT_DIR/endpoints"
    
    # Gau (Get All URLs)
    log "INFO" "Fetching URLs from Gau..."
    cat "$OUTPUT_DIR/recon/all_subdomains.txt" | gau --subs --threads 10 | anew "$OUTPUT_DIR/endpoints/gau.txt"
    
    # Katana (Active Crawling)
    log "INFO" "Crawling with Katana..."
    katana -list "$OUTPUT_DIR/probing/urls.txt" -silent -nc -jc -kf all -d 3 -o "$OUTPUT_DIR/endpoints/katana.txt"
    
    # Merge and Filter
    cat "$OUTPUT_DIR/endpoints/"*.txt | sort -u | anew "$OUTPUT_DIR/endpoints/all_urls.txt"
    
    # Extract JS files
    grep -E "\.js(\?|$)" "$OUTPUT_DIR/endpoints/all_urls.txt" | anew "$OUTPUT_DIR/endpoints/js_files.txt"
    
    # Extract Parameters for Fuzzing
    grep "=" "$OUTPUT_DIR/endpoints/all_urls.txt" | anew "$OUTPUT_DIR/endpoints/params.txt"

    # --- Advanced ID & UUID Extraction (For IDOR Hunting) ---
    log "ACT" "Extracting UUIDs and Modern IDs for IDOR analysis..."
    mkdir -p "$OUTPUT_DIR/endpoints/idor_prep"
    
    # Regex for UUID (v1-v5)
    grep -E "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}" "$OUTPUT_DIR/endpoints/all_urls.txt" | anew "$OUTPUT_DIR/endpoints/idor_prep/uuids.txt"
    
    # Regex for potential Hash IDs (MD5, SHA1, etc. in URLs)
    grep -E "/[0-9a-fA-F]{32}|/[0-9a-fA-F]{40}" "$OUTPUT_DIR/endpoints/all_urls.txt" | anew "$OUTPUT_DIR/endpoints/idor_prep/hash_ids.txt"
    
    # Extracting API endpoints that look like /api/v1/resource/ID
    grep -E "/api/v[0-9]/" "$OUTPUT_DIR/endpoints/all_urls.txt" | anew "$OUTPUT_DIR/endpoints/idor_prep/api_endpoints.txt"

    log "INFO" "UUIDs found: $(wc -l < "$OUTPUT_DIR/endpoints/idor_prep/uuids.txt" 2>/dev/null || echo 0)"
    log "INFO" "Total endpoints discovered: $(wc -l < "$OUTPUT_DIR/endpoints/all_urls.txt")"
}

# 4. Vulnerability Scanning (Nuclei)
vuln_scan() {
    log "ACT" "Running Nuclei Vulnerability Scan..."
    mkdir -p "$OUTPUT_DIR/vulns"
    
    # Run Nuclei on live hosts
    nuclei -l "$OUTPUT_DIR/probing/urls.txt" -severity critical,high,medium -silent -o "$OUTPUT_DIR/vulns/nuclei_results.txt"
    
    # Notify if findings (if notify is configured)
    if [ -s "$OUTPUT_DIR/vulns/nuclei_results.txt" ] && command -v notify &> /dev/null; then
        cat "$OUTPUT_DIR/vulns/nuclei_results.txt" | notify -silent
    fi
}

# 5. Advanced Fuzzing (FFUF)
fuzzing() {
    log "ACT" "Starting Smart Fuzzing..."
    mkdir -p "$OUTPUT_DIR/fuzzing"
    
    # Fuzzing for sensitive files on live hosts
    for url in $(cat "$OUTPUT_DIR/probing/urls.txt" | head -n 20); do
        local target_name=$(echo $url | sed 's/[^a-zA-Z0-9]/_/g')
        log "INFO" "Fuzzing $url..."
        ffuf -u "$url/FUZZ" -w "/home/ubuntu/muuf_pro/wordlists/dicc.txt" -mc 200,403 -silent -t 50 -o "$OUTPUT_DIR/fuzzing/$target_name.json"
    done
}

# --- Execution Flow ---
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

    if [ -z "$DOMAIN" ]; then
        log "ERR" "Domain is required. Use -d"
        exit 1
    fi

    if [ -z "$OUTPUT_DIR" ]; then
        OUTPUT_DIR="results/$DOMAIN-$(date +%Y%m%d_%H%M%S)"
    fi

    mkdir -p "$OUTPUT_DIR"
    log "INFO" "Output directory: $OUTPUT_DIR"
    
    check_deps
    recon
    probing
    endpoints
    vuln_scan
    
    log "INFO" "Scan completed for $DOMAIN"
    log "INFO" "Results saved in $OUTPUT_DIR"
}

main "$@"
