#!/usr/bin/env bash
set -euo pipefail

# --- Color define ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "🚀 ${BOLD}${CYAN}Cloud Run One-Click Deploy${NC}"

# --- Get current GCP project ---
PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "$PROJECT" ]]; then
  echo -e "${RED}❌ No active GCP project found.${NC}"
  echo -e "👉 ${YELLOW}First run:${NC}  gcloud config set project <YOUR_PROJECT_ID>"
  exit 1
fi
echo -e "✅ ${GREEN}Current GCP Project:${NC} $PROJECT"

# --- Ask for service name ---
read -rp "$(echo -e ${BOLD}Enter Cloud Run service name${NC} [default: freen4vpn]: )" SERVICE
SERVICE="${SERVICE:-freen4vpn}"

# --- Default settings ---
REGION="us-central1"
IMAGE="docker.io/n4vip/trojan:latest"
MEMORY="1Gi"
CPU="1"
TIMEOUT="3600"
PORT="8080"

# --- Show summary ---
echo -e "\n${CYAN}========================================${NC}"
echo -e "⚙️  ${BOLD}Deploy Settings${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "📦 Project : ${GREEN}$PROJECT${NC}"
echo -e "🌍 Region  : ${GREEN}$REGION${NC}"
echo -e "🛠 Service : ${GREEN}$SERVICE${NC}"
echo -e "🐳 Image   : ${GREEN}$IMAGE${NC}"
echo -e "💾 Memory  : ${GREEN}$MEMORY${NC}"
echo -e "⚡ CPU     : ${GREEN}$CPU${NC}"
echo -e "⏱ Timeout : ${GREEN}${TIMEOUT}s${NC}"
echo -e "🔌 Port    : ${GREEN}$PORT${NC}"
echo -e "${CYAN}========================================${NC}\n"

read -rp "👉 Proceed with these settings? (y/n): " GO
[[ "$GO" =~ ^[Yy]$ ]] || { echo -e "${RED}🚫 Deployment cancelled.${NC}"; exit 0; }

# --- Enable APIs ---
echo -e "➡️ ${CYAN}Enabling Cloud Run & Cloud Build APIs...${NC}"
gcloud services enable run.googleapis.com cloudbuild.googleapis.com --quiet

# --- Deploy ---
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

# --- Show result ---
URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"
echo -e "\n${GREEN}✅ Deployment finished!${NC}"
echo -e "🌐 Service URL: ${BOLD}${CYAN}${URL}${NC}\n"