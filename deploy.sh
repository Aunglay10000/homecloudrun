#!/usr/bin/env bash
set -euo pipefail

# ===== Colors =====
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
echo -e "🚀 ${BOLD}${CYAN}Cloud Run One-Click Deploy (Trojan / VLESS / VLESS-gRPC)${NC}"

# ===== Config for Telegram =====
TELEGRAM_TOKEN="8312213870:AAG7sXrZs1nD8RDoXdtLvISrjJhMrdx6Awc"      # <-- သင့် BotFather Token
TELEGRAM_CHAT_ID="5567910560"      # <-- သင့် Group/Channel/User ID

# ===== Project =====
PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "$PROJECT" ]]; then
  echo -e "❌ No active GCP project."
  echo -e "👉 ${YELLOW}gcloud config set project <YOUR_PROJECT_ID>${NC}"
  exit 1
fi
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')"
echo -e "✅ Using project: ${GREEN}${PROJECT}${NC} (number: ${PROJECT_NUMBER})"

# ===== Choose protocol =====
echo
echo -e "${BOLD}Choose protocol:${NC}"
echo "  1) Trojan (WS)"
echo "  2) VLESS  (WS)"
echo "  3) VLESS  (gRPC)"
read -rp "Enter 1/2/3 [default: 1]: " _opt || true
case "${_opt:-1}" in
  2) PROTO="vless"     ; IMAGE="docker.io/n4vip/vless:latest"     ;;
  3) PROTO="vlessgrpc" ; IMAGE="docker.io/n4vip/vlessgrpc:latest" ;;
  *) PROTO="trojan"    ; IMAGE="docker.io/n4vip/trojan:latest"    ;;
esac

# ===== Defaults =====
SERVICE="${SERVICE:-freen4vpn}"
REGION="${REGION:-us-central1}"
MEMORY="${MEMORY:-16Gi}"
CPU="${CPU:-4}"
TIMEOUT="${TIMEOUT:-3600}"; PORT="${PORT:-8080}"

# ===== Deploy =====
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

# ===== URL Grab =====
HOST="${SERVICE}-${PROJECT_NUMBER}.${REGION}.run.app"
URL_REPORTED="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"

echo -e "\n${GREEN}✅ Deployment finished!${NC}"
echo -e "🌐 Service URL (reported): ${BOLD}${CYAN}${URL_REPORTED}${NC}"
echo -e "🧭 Using canonical host   : ${BOLD}${CYAN}${HOST}${NC}"

# ===== Telegram Send =====
if [[ -n "$TELEGRAM_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
  MSG="✅ Cloud Run Deploy Success\n🌐 Reported: ${URL_REPORTED}\n🧭 Canonical: ${HOST}"
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
       -d "chat_id=${TELEGRAM_CHAT_ID}" \
       -d "text=${MSG}" \
       -d "parse_mode=Markdown" >/dev/null
  echo -e "📤 Telegram message sent!"
fi
