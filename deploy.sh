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

# ---------- Inputs (with sensible defaults; can override via env) ----------
SERVICE="${SERVICE:-freen4vpn}"        # export SERVICE=myservice bash deploy.sh  ဆိုပြီး override လုပ်လို့ရ
REGION="${REGION:-us-central1}"
IMAGE="${IMAGE:-docker.io/n4vip/trojan:latest}"
MEMORY="${MEMORY:-1Gi}"
CPU="${CPU:-1}"
TIMEOUT="${TIMEOUT:-3600}"
PORT="${PORT:-8080}"

# (Trojan link defaults)
TROJAN_PASS="${TROJAN_PASS:-Nanda}"                 # trojan://<password>@...
TROJAN_TAG="${TROJAN_TAG:-N4 GCP Hour Key}"        # human label (will be URL-encoded)
TROJAN_PATH_ESC="%2F%40n4vpn"                      # /@n4vpn
TROJAN_SNI="m.googleapis.com"                      # sni
TROJAN_ENTRY_HOST="m.googleapis.com"               # connect host
TROJAN_ALPN="http%2F1.1"                           # http/1.1
TROJAN_FP="randomized"                             # fingerprint
TROJAN_TYPE="ws"                                   # websocket

# ---------- Optional interactive prompt for service name ----------
read -rp "Enter Cloud Run service name [default: ${SERVICE}]: " _inp || true
SERVICE="${_inp:-$SERVICE}"

# ---------- Summary ----------
echo -e "\n${CYAN}========================================${NC}"
echo -e "⚙️  ${BOLD}Deploy Settings${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "📦 Project : ${GREEN}$PROJECT${NC}"
echo -e "🌍 Region  : ${GREEN}$REGION${NC}"
echo -e "🛠 Service : ${GREEN}$SERVICE${NC}"
# echo -e "🐳 Image   : ${GREEN}$IMAGE${NC}"   # ← Docker URL မဖော်ပြချင်လို့ comment ထား
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

# ---------- Get URL & host ----------
URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"
HOST="$(echo "$URL" | sed -E 's#^https?://([^/]+)/?.*#\1#')"

echo -e "\n${GREEN}✅ Deployment finished!${NC}"
echo -e "🌐 Service URL: ${BOLD}${CYAN}${URL}${NC}\n"

# ---------- Build Trojan URI (auto insert deployed host) ----------
TAG_ENC="${TROJAN_TAG// /%20}"  # simple space→%20
TROJAN_URI="trojan://${TROJAN_PASS}@${TROJAN_ENTRY_HOST}:443?path=${TROJAN_PATH_ESC}&security=tls&alpn=${TROJAN_ALPN}&host=${HOST}&fp=${TROJAN_FP}&type=${TROJAN_TYPE}&sni=${TROJAN_SNI}#${TAG_ENC}"

# ---------- Write files ----------
OUT_BASENAME="trojan_${SERVICE}"
TXT_FILE="${OUT_BASENAME}.txt"
URL_FILE="${OUT_BASENAME}.url"          # some clients accept .url or plain text

echo "${TROJAN_URI}" > "${TXT_FILE}"
echo "${TROJAN_URI}" > "${URL_FILE}"

echo -e "📝 Saved Trojan link to:"
echo -e "   - ${BOLD}${TXT_FILE}${NC}"
echo -e "   - ${BOLD}${URL_FILE}${NC}"

# ---------- Trigger Cloud Shell download (if available) ----------
if command -v cloudshell >/dev/null 2>&1; then
  echo -e "📥 Triggering Cloud Shell download..."
  # Try to download .txt first; fallback to .url if needed
  cloudshell download "${TXT_FILE}" || cloudshell download "${URL_FILE}" || true
  echo -e "✅ If the browser download didn't appear, you can also fetch from your Cloud Shell home directory."
else
  echo -e "${YELLOW}ℹ️ 'cloudshell' helper not found. Files are saved locally in Cloud Shell working directory.${NC}"
  echo -e "   You can manually download via editor or run:  cloudshell download ${TXT_FILE}"
fi

# ---------- Print URI for quick copy (optional) ----------
echo -e "\n🔗 Trojan URI:"
echo -e "${BOLD}${TROJAN_URI}${NC}\n"