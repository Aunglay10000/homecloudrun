#!/usr/bin/env bash
set -euo pipefail

##############################################
#  N4 Cloud Run One-Click (Stylish Edition)  #
##############################################

# ========== Palette & UI helpers ==========
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'

FG_CYAN='\033[38;5;44m'
FG_BLUE='\033[38;5;33m'
FG_GREEN='\033[38;5;46m'
FG_YELLOW='\033[38;5;226m'
FG_ORANGE='\033[38;5;214m'
FG_PINK='\033[38;5;205m'
FG_GREY='\033[38;5;245m'
FG_RED='\033[38;5;196m'

hr(){ printf "${FG_GREY}%s${RESET}\n" "────────────────────────────────────────────────────────"; }
title(){
  printf "\n${FG_CYAN}╭──────────────────────────────────────────────────────╮\n"
  printf "│  ${BOLD}🚀 N4 Cloud Run One-Click${RESET}${FG_CYAN} — ${ITALIC}Trojan / VLESS / gRPC${RESET}${FG_CYAN}     │\n"
  printf "╰──────────────────────────────────────────────────────╯${RESET}\n"
}
section(){ printf "\n${FG_BLUE}◇ %s${RESET}\n" "$1"; hr; }
ok(){ printf "${FG_GREEN}✔${RESET} %s\n" "$1"; }
warn(){ printf "${FG_ORANGE}⚠${RESET} %s\n" "$1"; }
err(){ printf "${FG_RED}✘ %s${RESET}\n" "$1"; }
kv(){ printf "  ${FG_GREY}%s${RESET}  %s\n" "$1" "$2"; }   # key/value line

# ========== Telegram Config (hardcode or override later) ==========
TELEGRAM_TOKEN="${TELEGRAM_TOKEN:-8312213870:AAG7sXrZs1nD8RDoXdtLvISrjJhMrdx6Awc}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-5567910560}"

# ========== Start banner ==========
title

# ========== Project ==========
section "Project"
PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "$PROJECT" ]]; then
  err "No active GCP project."
  echo "  👉 ${BOLD}gcloud config set project <YOUR_PROJECT_ID>${RESET}"
  exit 1
fi
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')"
ok "Project loaded"
kv "Project:"       "${BOLD}${PROJECT}${RESET}"
kv "Project No.:"   "${PROJECT_NUMBER}"

# ========== Protocol ==========
section "Choose Protocol"
printf "  ${FG_PINK}1) Trojan (WS)   2) VLESS (WS)   3) VLESS (gRPC)${RESET}\n"
read -rp "  Enter 1/2/3 [default: 1]: " _opt || true
case "${_opt:-1}" in
  2) PROTO="vless"     ; IMAGE="docker.io/n4vip/vless:latest"     ;;
  3) PROTO="vlessgrpc" ; IMAGE="docker.io/n4vip/vlessgrpc:latest" ;;
  *) PROTO="trojan"    ; IMAGE="docker.io/n4vip/trojan:latest"    ;;
esac
ok "Protocol: ${BOLD}${PROTO}${RESET}"

# ========== Defaults ==========
SERVICE="${SERVICE:-freen4vpn}"
REGION="${REGION:-us-central1}"
MEMORY="${MEMORY:-16Gi}"
CPU="${CPU:-4}"
TIMEOUT="${TIMEOUT:-3600}"
PORT="${PORT:-8080}"

section "Deploy Config"
kv "Service:"       "${BOLD}${SERVICE}${RESET}"
kv "Region:"        "${REGION}"
kv "CPU / Memory:"  "${CPU} vCPU  /  ${MEMORY}"
kv "Timeout/Port:"  "${TIMEOUT}s  /  ${PORT}"
kv "Image:"         "${IMAGE}"

# ========== Keys (same logic) ==========
TROJAN_PASS="Nanda"
TROJAN_TAG="N4%20GCP%20Hour%20Key"
TROJAN_PATH="%2F%40n4vpn"   # /@n4vpn

VLESS_UUID="0c890000-4733-b20e-067f-fc341bd20000"
VLESS_PATH="%2FN4VPN"       # /N4VPN
VLESS_TAG="N4%20GCP%20VLESS"

VLESSGRPC_UUID="0c890000-4733-b20e-067f-fc341bd20000"
VLESSGRPC_SVC="n4vpnfree-grpc"
VLESSGRPC_TAG="GCP-VLESS-GRPC"

# ========== Service Name ==========
read -rp "  Service name [default: ${SERVICE}]: " _svc || true
SERVICE="${_svc:-$SERVICE}"

# ========== Enable APIs & Deploy ==========
section "Enable APIs"
gcloud services enable run.googleapis.com cloudbuild.googleapis.com --quiet
ok "APIs enabled"

section "Deploying to Cloud Run"
gcloud run deploy "$SERVICE" \
  --image="$IMAGE" \
  --platform=managed \
  --region="$REGION" \
  --memory="$MEMORY" \
  --cpu="$CPU" \
  --timeout="$TIMEOUT" \
  --allow-unauthenticated \
  --port="$PORT" \
  --quiet
ok "Deployed"

# ========== Canonical URL ONLY ==========
CANONICAL_HOST="${SERVICE}-${PROJECT_NUMBER}.${REGION}.run.app"
URL_CANONICAL="https://${CANONICAL_HOST}"

section "Result"
ok "Service is ready"
kv "URL:" "${FG_CYAN}${BOLD}${URL_CANONICAL}${RESET}"

# ========== Build Final Client URL (canonical host only) ==========
LABEL=""; URI=""
case "$PROTO" in
  trojan)
    URI="trojan://${TROJAN_PASS}@m.googleapis.com:443?path=${TROJAN_PATH}&security=tls&alpn=http%2F1.1&host=${CANONICAL_HOST}&fp=randomized&type=ws&sni=m.googleapis.com#${TROJAN_TAG}"
    LABEL="TROJAN URL"
    ;;
  vless)
    URI="vless://${VLESS_UUID}@m.googleapis.com:443?path=${VLESS_PATH}&security=tls&alpn=http%2F1.1&encryption=none&host=${CANONICAL_HOST}&fp=randomized&type=ws&sni=m.googleapis.com#${VLESS_TAG}"
    LABEL="VLESS URL (WS)"
    ;;
  vlessgrpc)
    URI="vless://${VLESSGRPC_UUID}@m.googleapis.com:443?mode=gun&security=tls&alpn=http%2F1.1&encryption=none&fp=randomized&type=grpc&serviceName=${VLESSGRPC_SVC}&sni=${CANONICAL_HOST}#${VLESSGRPC_TAG}"
    LABEL="VLESS-gRPC URL"
    ;;
esac

section "Client Key"
printf "  ${FG_YELLOW}${BOLD}%s${RESET}\n" "${LABEL}"
printf "  ${FG_GREY}Copy below:${RESET}\n"
printf "  ${FG_ORANGE}▎${RESET} %s\n" "${URI}"
hr

# ========== Telegram Push (pretty, copy-friendly) ==========
if [[ -n "${TELEGRAM_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
  section "Telegram"
  HTML_MSG=$(
    cat <<EOF
<b>✅ Cloud Run Deploy Success</b>
<b>Service:</b> ${SERVICE}
<b>Region:</b> ${REGION}
<b>URL:</b> ${URL_CANONICAL}

<pre><code>${URI}</code></pre>
EOF
  )
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
       -d "chat_id=${TELEGRAM_CHAT_ID}" \
       --data-urlencode "text=${HTML_MSG}" \
       -d "parse_mode=HTML" >/dev/null \
    && ok "Telegram message sent"
else
  warn "Telegram not configured (TELEGRAM_TOKEN / TELEGRAM_CHAT_ID empty)"
fi

printf "\n${FG_GREEN}${BOLD}All done. Enjoy!${RESET} ✨\n"
