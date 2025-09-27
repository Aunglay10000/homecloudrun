#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
echo -e "🚀 ${BOLD}${CYAN}Cloud Run One-Click Deploy${NC}"

# ---------- GCP ----------
PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "$PROJECT" ]]; then
  echo -e "${RED}❌ No active GCP project found.${NC}"
  echo -e "👉 ${YELLOW}Run:${NC}  gcloud config set project <YOUR_PROJECT_ID>"
  exit 1
fi
echo -e "✅ ${GREEN}Current GCP Project:${NC} $PROJECT"

SERVICE="${SERVICE:-freen4vpn}"
REGION="${REGION:-us-central1}"
IMAGE="${IMAGE:-docker.io/n4vip/trojan:latest}"
MEMORY="${MEMORY:-1Gi}"
CPU="${CPU:-1}"
TIMEOUT="${TIMEOUT:-3600}"
PORT="${PORT:-8080}"

# ---------- Trojan Defaults ----------
TROJAN_PASS="${TROJAN_PASS:-Nanda}"
TROJAN_TAG="${TROJAN_TAG:-N4 GCP Hour Key}"
TROJAN_PATH_ESC="%2F%40n4vpn"
TROJAN_SNI="m.googleapis.com"
TROJAN_ENTRY_HOST="m.googleapis.com"
TROJAN_ALPN="http%2F1.1"
TROJAN_FP="randomized"
TROJAN_TYPE="ws"

read -rp "Enter Cloud Run service name [default: ${SERVICE}]: " _inp || true
SERVICE="${_inp:-$SERVICE}"

echo -e "\n${CYAN}========================================${NC}"
echo -e "📦 Project : ${GREEN}$PROJECT${NC}"
echo -e "🌍 Region  : ${GREEN}$REGION${NC}"
echo -e "🛠 Service : ${GREEN}$SERVICE${NC}"
echo -e "💾 Memory  : ${GREEN}$MEMORY${NC}"
echo -e "⚡ CPU     : ${GREEN}$CPU${NC}"
echo -e "⏱ Timeout : ${GREEN}${TIMEOUT}s${NC}"
echo -e "🔌 Port    : ${GREEN}$PORT${NC}"
echo -e "${CYAN}========================================${NC}\n"

read -rp "Proceed? (y/n): " GO || true
[[ "$GO" =~ ^[Yy]$ ]] || { echo -e "${RED}🚫 Cancelled${NC}"; exit 0; }

echo -e "➡️ ${CYAN}Enable Cloud Run API...${NC}"
gcloud services enable run.googleapis.com cloudbuild.googleapis.com --quiet

echo -e "➡️ ${CYAN}Deploying...${NC}"
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

URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"
HOST="$(echo "$URL" | sed -E 's#^https?://([^/]+)/?.*#\1#')"
echo -e "\n${GREEN}✅ Finished${NC}"
echo -e "🌐 Service URL: ${BOLD}${CYAN}${URL}${NC}"

TAG_ENC="${TROJAN_TAG// /%20}"
TROJAN_URI="trojan://${TROJAN_PASS}@${TROJAN_ENTRY_HOST}:443?path=${TROJAN_PATH_ESC}&security=tls&alpn=${TROJAN_ALPN}&host=${HOST}&fp=${TROJAN_FP}&type=${TROJAN_TYPE}&sni=${TROJAN_SNI}#${TAG_ENC}"

OUT_FILE="trojan_${SERVICE}.txt"
echo -n "${TROJAN_URI}" > "${OUT_FILE}"

# --------- Pastebin Upload ----------
PASTEBIN_DEV_KEY="a4SeEKNHX0CzZ3-10SP5Qae-5L1-xmRd"
echo -e "➡️ ${CYAN}Uploading to Pastebin...${NC}"

PB_RESP=$(curl -s \
  -d "api_dev_key=${PASTEBIN_DEV_KEY}" \
  -d "api_option=paste" \
  -d "api_paste_code=$(cat "${OUT_FILE}")" \
  -d "api_paste_private=1" \
  -d "api_paste_name=${OUT_FILE}" \
  https://pastebin.com/api/api_post.php)

if [[ "$PB_RESP" =~ ^https?://pastebin\.com/ ]]; then
  RAW_URL=$(echo "$PB_RESP" | sed -E 's#https?://pastebin\.com/([A-Za-z0-9]+)#https://pastebin.com/raw/\1#')
  echo -e "🌐 ${GREEN}Pastebin Link:${NC} ${CYAN}${PB_RESP}${NC}"
  echo -e "📄 ${GREEN}Raw URL:${NC} ${CYAN}${RAW_URL}${NC}"
else
  echo -e "${YELLOW}⚠️ Pastebin failed. Trying 0x0.st ...${NC}"
  DL_URL=$(curl -s -F "file=@${OUT_FILE}" https://0x0.st || true)
  if [[ "$DL_URL" =~ ^https?://0x0\.st/ ]]; then
    echo -e "🌐 ${GREEN}0x0.st Link:${NC} ${CYAN}${DL_URL}${NC}"
  else
    echo -e "${RED}⚠️ Both Pastebin & 0x0.st failed. File kept locally: ${OUT_FILE}${NC}"
    if command -v cloudshell >/dev/null 2>&1; then
      cloudshell download "${OUT_FILE}" || true
    fi
  fi
fi

echo -e "\n🔗 Trojan URI:"
echo -e "${BOLD}${TROJAN_URI}${NC}\n"
