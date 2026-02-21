#!/bin/bash
# VULTR INVESTIGATION TOOL

if [ -f "$HOME/.env" ]; then
    source "$HOME/.env"
else
    echo -e "\033[0;31m[!] Error: ~/.env file not found.\033[0m"
    echo "    Please ensure your .env file is in your home directory ($HOME/)."
    return 1 2>/dev/null || exit 1
fi

PROXY_PORT=1080
SSH_USER="root"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

function _check_deps() {
    for cmd in jq curl vultr-cli nc; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${RED}[!] Critical dependency missing: $cmd${NC}"; return 1
        fi
    done
}

function _get_investigator_id() {
    vultr-cli instance list -o json | jq -r '.instances[] | select(.label == "investigator") | .id'
}

function _get_location_name() {
    case $1 in
        "ewr") echo "USA (New Jersey)" ;; "ord") echo "USA (Chicago)" ;; "lax") echo "USA (Los Angeles)" ;;
        "yto") echo "Canada (Toronto)" ;; "mex") echo "Mexico (Mexico City)" ;; "gru") echo "Brazil (São Paulo)" ;;
        "scl") echo "Chile (Santiago)" ;; "lhr") echo "UK (London)" ;; "ams") echo "Netherlands (Amsterdam)" ;;
        "fra") echo "Germany (Frankfurt)" ;; "cdg") echo "France (Paris)" ;; "mad") echo "Spain (Madrid)" ;;
        "waw") echo "Poland (Warsaw)" ;; "sto") echo "Sweden (Stockholm)" ;; "jnb") echo "South Africa (Johannesburg)" ;;
        "tlv") echo "Israel (Tel Aviv)" ;; "bom") echo "India (Mumbai)" ;; "nrt") echo "Japan (Tokyo)" ;;
        "icn") echo "South Korea (Seoul)" ;; "sgp") echo "Singapore" ;; "syd") echo "Australia (Sydney)" ;;
        *) echo "Unknown Region ($1)" ;;
    esac
}

function help-investigation() {
    echo -e "${CYAN}${BOLD}=== VULTR INVESTIGATION TOOL HELP ===${NC}"
    echo -e "  ${BOLD}start-investigation [code]${NC}  : Deploy server"
    echo -e "  ${BOLD}stop-investigation${NC}         : Destroy server"
    echo -e "  ${BOLD}reconnect-investigation${NC}    : Fix tunnel manually"
    echo -e "  ${BOLD}watch-investigation${NC}        : Start Keep-Alive Auto-Reconnect Monitor"
    echo -e "  ${BOLD}status-investigation${NC}       : Check status & location"
    echo -e "  ${BOLD}locations-investigation${NC}    : Show all country codes"
}

function locations-investigation() {
    echo -e "${CYAN}${BOLD}=== AVAILABLE GLOBAL LOCATIONS ===${NC}"
    echo -e "${YELLOW}North America:${NC}"
    echo -e "  usa-east (New Jersey) | usa-mid (Chicago) | usa-west (Los Angeles)"
    echo -e "  ca (Toronto) | mx (Mexico City)"
    echo -e "${YELLOW}South America:${NC}"
    echo -e "  br (São Paulo) | cl (Santiago)"
    echo -e "${YELLOW}Europe:${NC}"
    echo -e "  uk (London) | de (Frankfurt) | nl (Amsterdam) | fr (Paris)"
    echo -e "  es (Madrid) | pl (Warsaw) | se (Stockholm)"
    echo -e "${YELLOW}Asia & Oceania:${NC}"
    echo -e "  jp (Tokyo) | kr (Seoul) | sg (Singapore) | in (Mumbai) | au (Sydney)"
    echo -e "${YELLOW}Middle East & Africa:${NC}"
    echo -e "  il (Tel Aviv) | za (Johannesburg)"
    echo -e "${BLUE}Usage example: start-investigation se${NC}"
}

function start-investigation() {
    _check_deps || return 1
    INPUT_COUNTRY=$(echo "${1:-de}" | tr '[:upper:]' '[:lower:]')

    EXISTING_ID=$(_get_investigator_id)
    if [ ! -z "$EXISTING_ID" ]; then
        echo -e "${RED}[!] Server already running (ID: $EXISTING_ID).${NC}"
        echo "    Run 'watch-investigation' or 'stop-investigation'."
        return 1
    fi

    case $INPUT_COUNTRY in
        "usa-east"|"us") REGION="ewr" ;; "usa-mid") REGION="ord" ;; "usa-west") REGION="lax" ;;
        "ca") REGION="yto" ;; "mx") REGION="mex" ;; "br") REGION="gru" ;; "cl") REGION="scl" ;;
        "uk") REGION="lhr" ;; "de") REGION="fra" ;; "nl") REGION="ams" ;; "fr") REGION="cdg" ;;
        "es") REGION="mad" ;; "pl") REGION="waw" ;; "se") REGION="sto" ;; "za") REGION="jnb" ;;
        "il") REGION="tlv" ;; "in") REGION="bom" ;; "jp") REGION="nrt" ;; "kr") REGION="icn" ;;
        "sg") REGION="sgp" ;; "au") REGION="syd" ;;
        *) echo -e "${RED}[!] Unknown country code. Run 'locations-investigation' for options.${NC}"; return 1 ;;
    esac

    LOC_NAME=$(_get_location_name $REGION)
    echo -e "${BLUE}[*] Deploying in: ${BOLD}$LOC_NAME${NC} ${BLUE}($REGION)...${NC}"
    
    KEY_ID=$(vultr-cli ssh-key list -o json | jq -r --arg KNAME "$SSH_KEY_NAME" '.ssh_keys[] | select(.name == $KNAME) | .id')
    if [ -z "$KEY_ID" ]; then echo -e "${RED}[!] SSH Key '$SSH_KEY_NAME' not found.${NC}"; return 1; fi

    RESPONSE=$(vultr-cli instance create --region $REGION --plan vc2-1c-1gb --os 1743 --label investigator --ssh-keys "$KEY_ID" --ipv6 true --output json 2>&1)
    if echo "$RESPONSE" | grep -iq "error"; then echo -e "${RED}[!] API Error: $RESPONSE${NC}"; return 1; fi
    ID=$(echo "$RESPONSE" | jq -r '.instance.id')
    
    echo -e "${GREEN}[+] Server ID: $ID created.${NC}"

    echo -e "${BLUE}[*] Waiting for IP ...${NC}"
    IP=""
    while [ -z "$IP" ] || [ "$IP" == "0.0.0.0" ] || [ "$IP" == "null" ]; do
        sleep 5
        IP=$(vultr-cli instance get $ID --output json | jq -r '.instance.main_ip')
    done
    echo -e "${GREEN}[+] IP Assigned: $IP${NC}"

    echo -e "${BLUE}[*] Waiting for SSH service (45s)... ${NC}"
    COUNT=0
    while ! nc -z -w 2 $IP 22; do
        printf "."
        sleep 5
        ((COUNT++))
        if [ $COUNT -gt 60 ]; then echo -e "${RED}[!] SSH Timed out.${NC}"; return 1; fi
    done
    echo ""

    echo -e "${BLUE}[*] Allowing cloud-init to configure IPv6 (15s)...${NC}"
    sleep 15
    reconnect-investigation
}

function reconnect-investigation() {
    _check_deps || return 1
    ID=$(_get_investigator_id)
    if [ -z "$ID" ]; then echo -e "${RED}[!] No active server found.${NC}"; return 1; fi
    IP=$(vultr-cli instance get $ID --output json | jq -r '.instance.main_ip')

    if lsof -Pi :$PROXY_PORT -sTCP:LISTEN -t >/dev/null ; then
        kill $(lsof -Pi :$PROXY_PORT -sTCP:LISTEN -t) 2>/dev/null
    fi

    if [ -z "$SSH_AUTH_SOCK" ]; then
        eval "$(ssh-agent -s)" > /dev/null
    fi
    KEY_FINGERPRINT=$(ssh-keygen -lf "$SSH_KEY_PATH" | awk '{print $2}')
    if ! ssh-add -l >/dev/null 2>&1 || ! ssh-add -l | grep -q "$KEY_FINGERPRINT"; then
        echo -e "${YELLOW}[*] Unlocking SSH Key for this session...${NC}"
        ssh-add "$SSH_KEY_PATH"
    fi

    echo -e "${BLUE}[*] Opening Secure Tunnel to $IP... ${NC}"

    ssh -q -f -D $PROXY_PORT -N \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=10 \
        -o ServerAliveInterval=60 \
        -i "$SSH_KEY_PATH" "$SSH_USER@$IP"

    sleep 2

    if lsof -Pi :$PROXY_PORT -sTCP:LISTEN -t >/dev/null; then
        DETECTED_IP=$(curl -s --max-time 10 --socks5-hostname 127.0.0.1:$PROXY_PORT https://ipv4.icanhazip.com)
        if [ "$DETECTED_IP" == "$IP" ]; then
            echo -e "${GREEN}[SUCCESS] Tunnel Active & Traffic Verified! (IP: $DETECTED_IP)${NC}"
            echo -e "${RED}${BOLD}ACTION: TURN ON FOXYPROXY (SOCKS5 127.0.0.1:$PROXY_PORT)${NC}"
            return 0
        else
            echo -e "${RED}[FAIL] Verification failed. Got: $DETECTED_IP${NC}"
            return 1
        fi
    else
        echo -e "${RED}[!] Tunnel failed to start.${NC}"
        return 1
    fi
}

function watch-investigation() {
    echo -e "${CYAN}${BOLD}[*] Starting Keep-Alive Monitor. (Press Ctrl+C to exit monitor)${NC}"
    echo -e "${YELLOW}    You can let your VM sleep. It will auto-reconnect when it wakes up.${NC}"
    
    while true; do
        if ! curl -s --max-time 5 --socks5-hostname 127.0.0.1:$PROXY_PORT https://ipv4.icanhazip.com > /dev/null; then
            echo -e "\n${RED}[!] Tunnel drop detected at $(date +%H:%M:%S). Reconnecting...${NC}"
            reconnect-investigation
        fi
        sleep 10
    done
}

function status-investigation() {
    ID=$(_get_investigator_id)
    if [ -z "$ID" ]; then
        echo -e "${RED}[-] No investigator running.${NC}"
    else
        DATA=$(vultr-cli instance get $ID --output json)
        REGION_CODE=$(echo "$DATA" | jq -r '.instance.region')
        LOC_NAME=$(_get_location_name $REGION_CODE)
        
        echo -e "${GREEN}${BOLD}[+] ACTIVE INVESTIGATOR${NC}"
        echo -e "    ${BOLD}Location:${NC} $LOC_NAME ($REGION_CODE)"
        echo -e "    ${BOLD}IPv4:${NC}     $(echo "$DATA" | jq -r '.instance.main_ip')"
    fi
}

function stop-investigation() {
    ID=$(_get_investigator_id)
    if [ -z "$ID" ]; then
        echo -e "${RED}[!] No server found.${NC}"
    else
        echo -e "${YELLOW}[*] Destroying... ${NC}"
        vultr-cli instance delete $ID
        pkill -f "ssh -q -f -D"
        echo -e "${GREEN}[+] Destroyed.${NC}"
    fi
}