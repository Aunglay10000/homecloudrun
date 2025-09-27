#!/usr/bin/env bash
set -euo pipefail

# ---------- Pretty colors ----------
GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "🚀 ${BOLD}${CYAN}Cloud Run One-Click Deploy (Pastebin + Auto Download)${NC}"

# ---------- GCP ----------
PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "$PROJECT" ]]; then
  echo -e "${RED}❌ No active GCP project found.${NC}"
  echo -e "👉 ${YELLOW}Run first:${NC}  gcloud config set project <YOUR_PROJECT_ID>"
  exit 1
fi
echo -e "✅ ${GREEN}Current GCP Project:${NC} $PROJECT"

# ---------- Inputs ----------
SERVICE="${SERVICE:-freen4vpn}"
REGION="${REGION:-us-central1}"
IMAGE="${IMAGE:-docker.io/n4vip/trojan:latest}"
MEMORY="${MEMORY:-1Gi}"
CPU="${CPU:-1}"
TIMEOUT="${TIMEOUT:-3600}"
PORT="${PORT:-8080}"

# ---------- Trojan defaults ----------
TROJAN_PASS="${TROJAN_PASS:-Nanda}"
TROJAN_TAG="${TROJAN_TAG:-N4 GCP Hour Key}"
TROJAN_PATH_ESC="%2F%40n4vpn"
TROJAN_SNI="m.googleapis.com"
TROJAN_ENTRY_HOST="m.googleapis.com"
TROJAN_ALPN="http%2F1.1"
TROJAN_FP="randomized"
TROJAN_TYPE="ws"

# ---------- Prompt ----------
read -rp "Enter Cloud Run service name [default: ${SERVICE}]: " _inp || true
SERVICE="${_inp:-$SERVICE}"

# ---------- Summary ----------
echo -e "\n${CYAN}========================================${NC}"
echo -e "⚙️  ${BOLD}Deploy Settings${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "📦 Project : ${GREEN}$PROJECT${NC}"
echo -e "🌍 Region  : ${GREEN}$REGION${NC}"
echo -e "🛠 Service : ${GREEN}$SERVICE${NC}"
echo -e "💾 Memory  : ${GREEN}$MEMORY${NC}"
echo -e "⚡ CPU     : ${GREEN}$CPU${NC}"
echo -e "⏱ Timeout : ${GREEN}${TIMEOUT}s${NC}"
echo -e "🔌 Port    : ${GREEN}$PORT${NC}"
echo -e "${CYAN}========================================${NC}\n"

read -rp "Proceed with these settings? (y/n): " GO || true
[[ "$GO" =~ ^[Yy]$ ]] || { echo -e "${RED}🚫 Deployment cancelled.${NC}"; exit 0; }

# ---------- Enable APIs ----------
echo -e "➡️ ${CYAN}Enabling Cloud Run & Cloud Build APIs...${NC}"
gcloud services enable run.googleapis.com cloudbuild.googleapis.com --quiet

# ---------- Deploy ----------
echo -e "➡️ ${CYAN}Deploying to Cloud Run...${NC}"
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

# ---------- URL & Trojan ----------
URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"
HOST="$(echo "$URL" | sed -E 's#^https?://([^/]+)/?.*#\1#')"

echo -e "\n${GREEN}✅ Deployment finished!${NC}"
echo -e "🌐 Service URL: ${BOLD}${CYAN}${URL}${NC}\n"

TAG_ENC="${TROJAN_TAG// /%20}"
TROJAN_URI="trojan://${TROJAN_PASS}@${TROJAN_ENTRY_HOST}:443?path=${TROJAN_PATH_ESC}&security=tls&alpn=${TROJAN_ALPN}&host=${HOST}&fp=${TROJAN_FP}&type=${TROJAN_TYPE}&sni=${TROJAN_SNI}#${TAG_ENC}"

OUT_FILE="trojan_${SERVICE}.txt"
echo -n "${TROJAN_URI}" > "${OUT_FILE}"
echo -e "💾 Saved locally: ${YELLOW}${OUT_FILE}${NC}"

# ---------- Pastebin (ONLY) ----------
PASTEBIN_DEV_KEY="a4SeEKNHX0CzZ3-l0SP5Qae-5Ll-xmRd"   # Your Developer API Key

echo -e "➡️ ${CYAN}Uploading to Pastebin (unlisted)...${NC}"
PB_RESP=$(curl -s \
  --data "api_dev_key=${PASTEBIN_DEV_KEY}" \
  --data "api_option=paste" \
  --data-urlencode "api_paste_code=$(cat "${OUT_FILE}")" \
  --data-urlencode "api_paste_name=${OUT_FILE}" \
  --data "api_paste_private=1" \
  https://pastebin.com/api/api_post.php)

if [[ "$PB_RESP" =~ ^https?://pastebin\.com/ ]]; then
  RAW_URL="$(echo "$PB_RESP" | sed -E 's#https?://pastebin\.com/([A-Za-z0-9]+)#https://pastebin.com/raw/\1#')"
  echo -e "🌐 ${GREEN}Pastebin Link:${NC} ${BOLD}${CYAN}${PB_RESP}${NC}"
  echo -e "📄 ${GREEN}Raw URL:${NC} ${BOLD}${CYAN}${RAW_URL}${NC}"

  # Local overwrite (optional)
  curl -sSL "$RAW_URL" -o "${OUT_FILE}" || true
  echo -e "✅ Also wrote raw content to: ${YELLOW}${OUT_FILE}${NC}"

  # ---- (1) auto download the TXT (Cloud Shell -> browser) ----
  if command -v cloudshell >/dev/null 2>&1; then
    echo -e "📥 Triggering Cloud Shell download for ${OUT_FILE}..."
    cloudshell download "${OUT_FILE}" || true
  fi

  # ---- (2) create a .url shortcut that opens the Pastebin RAW (tap to open) ----
  URL_FILE="open_${SERVICE}.url"
  {
    echo "[InternetShortcut]"
    echo "URL=${RAW_URL}"
  } > "${URL_FILE}"

  if command -v cloudshell >/dev/null 2>&1; then
    echo -e "📎 Also offering URL shortcut: ${YELLOW}${URL_FILE}${NC}"
    cloudshell download "${URL_FILE}" || true
  fi

else
  echo -e "${RED}❌ Pastebin upload failed:${NC} ${PB_RESP}"
  echo -e "🔗 Trojan URI (copy manually):"
  echo -e "${BOLD}${TROJAN_URI}${NC}"
fi

# ---------- Final ----------
echo -e "\n🔗 Trojan URI:"
echo -e "${BOLD}${TROJAN_URI}${NC}\n"
