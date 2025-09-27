#!/usr/bin/env bash
set -euo pipefail

# ---------- Pretty colors ----------
GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "🚀 ${BOLD}${CYAN}Cloud Run One-Click Deploy${NC}"

# ---------- Get current project ----------
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

# (Trojan link defaults)
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

# ---------- Get URL & build Trojan link ----------
URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"
HOST="$(echo "$URL" | sed -E 's#^https?://([^/]+)/?.*#\1#')"

echo -e "\n${GREEN}✅ Deployment finished!${NC}"
echo -e "🌐 Service URL: ${BOLD}${CYAN}${URL}${NC}\n"

TAG_ENC="${TROJAN_TAG// /%20}"
TROJAN_URI="trojan://${TROJAN_PASS}@${TROJAN_ENTRY_HOST}:443?path=${TROJAN_PATH_ESC}&security=tls&alpn=${TROJAN_ALPN}&host=${HOST}&fp=${TROJAN_FP}&type=${TROJAN_TYPE}&sni=${TROJAN_SNI}#${TAG_ENC}"

# ---------- Upload to 0x0.st ----------
echo -e "➡️ ${CYAN}Uploading Trojan link to 0x0.st ...${NC}"
DL_URL=$(echo -n "${TROJAN_URI}" | curl -s -F 'file=@-' https://0x0.st)

if [[ -n "$DL_URL" ]]; then
  echo -e "🌐 ${GREEN}Download Link:${NC} ${BOLD}${CYAN}${DL_URL}${NC}"
  echo -e "\n💡 ${YELLOW}👉 Click this link to directly download your trojan config file.${NC}"
else
  echo -e "${RED}⚠️ Upload to 0x0.st failed.${NC}"
  echo -e "🔗 Trojan URI:"
  echo -e "${BOLD}${TROJAN_URI}${NC}"
fi
