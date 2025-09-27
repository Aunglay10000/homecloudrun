#!/usr/bin/env bash
set -euo pipefail

# ----- Pretty colors (optional) -----
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "🚀 ${BOLD}${CYAN}Cloud Run One-Click Deploy${NC}"

# ----- GCP project -----
PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "$PROJECT" ]]; then
  echo -e "❌ No active GCP project."
  echo -e "👉 Run: ${YELLOW}gcloud config set project <YOUR_PROJECT_ID>${NC}"
  exit 1
fi
echo -e "✅ Using project: ${GREEN}${PROJECT}${NC}"

# ----- Defaults (override with env if you like) -----
SERVICE="${SERVICE:-freen4vpn}"
REGION="${REGION:-us-central1}"
IMAGE="${IMAGE:-docker.io/n4vip/trojan:latest}"
MEMORY="${MEMORY:-1Gi}"
CPU="${CPU:-1}"
TIMEOUT="${TIMEOUT:-3600}"
PORT="${PORT:-8080}"

# Trojan params
TROJAN_PASS="${TROJAN_PASS:-Nanda}"
TROJAN_TAG="${TROJAN_TAG:-N4 GCP Hour Key}"
TROJAN_PATH_ESC="%2F%40n4vpn"          # /@n4vpn
TROJAN_SNI="m.googleapis.com"
TROJAN_ENTRY_HOST="m.googleapis.com"
TROJAN_ALPN="http%2F1.1"
TROJAN_FP="randomized"
TROJAN_TYPE="ws"

# ----- Ask service name only (no y/n confirm) -----
read -rp "Enter Cloud Run service name [default: ${SERVICE}]: " _inp || true
SERVICE="${_inp:-$SERVICE}"

# ----- Summary (info only) -----
echo -e "\n${CYAN}========================================${NC}"
echo -e "📦 Project : ${PROJECT}"
echo -e "🌍 Region  : ${REGION}"
echo -e "🛠 Service : ${SERVICE}"
echo -e "💾 Memory  : ${MEMORY}"
echo -e "⚡ CPU     : ${CPU}"
echo -e "⏱ Timeout : ${TIMEOUT}s"
echo -e "🔌 Port    : ${PORT}"
echo -e "${CYAN}========================================${NC}\n"

# ----- Enable APIs & Deploy -----
echo -e "➡️ Enabling Cloud Run & Cloud Build APIs..."
gcloud services enable run.googleapis.com cloudbuild.googleapis.com --quiet

echo -e "➡️ Deploying to Cloud Run..."
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

# ----- Get URL & build Trojan URI -----
URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"
HOST="$(echo "$URL" | sed -E 's#^https?://([^/]+)/?.*#\1#')"
TAG_ENC="${TROJAN_TAG// /%20}"

TROJAN_URI="trojan://${TROJAN_PASS}@${TROJAN_ENTRY_HOST}:443?path=${TROJAN_PATH_ESC}&security=tls&alpn=${TROJAN_ALPN}&host=${HOST}&fp=${TROJAN_FP}&type=${TROJAN_TYPE}&sni=${TROJAN_SNI}#${TAG_ENC}"

# ----- Final output (just show) -----
echo -e "\n${GREEN}✅ Deployment finished!${NC}"
echo -e "🌐 Service URL:"
echo -e "   ${BOLD}${CYAN}${URL}${NC}"
echo -e "\n🔗 Trojan URL (copy & use in client):"
echo -e "   ${BOLD}${TROJAN_URI}${NC}\n"
