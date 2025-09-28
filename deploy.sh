#!/usr/bin/env bash
set -euo pipefail

# ===== Pretty Colors =====
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
echo -e "🚀 ${BOLD}${CYAN}Cloud Run One-Click Deploy (Trojan / VLESS / VLESS-gRPC)${NC}"

# ===== GCP Project =====
PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "$PROJECT" ]]; then
  echo -e "❌ No active GCP project."
  read -rp "👉 Enter your GCP Project ID to use: " PROJECT
  if [[ -z "$PROJECT" ]]; then
    echo -e "⚠️ Project ID is required. Exiting."; exit 1
  fi
  gcloud config set project "$PROJECT"
fi
echo -e "✅ Using project: ${GREEN}${PROJECT}${NC}"

# ===== Global Defaults =====
SERVICE="${SERVICE:-freen4vpn}"
REGION="${REGION:-us-central1}"
MEMORY="${MEMORY:-1Gi}"
CPU="${CPU:-1}"
TIMEOUT="${TIMEOUT:-3600}"
PORT="${PORT:-8080}"

# ===== Docker Images =====
IMG_TROJAN="docker.io/n4vip/trojan:latest"
IMG_VLESS="docker.io/n4vip/vless:latest"
IMG_VLESSGRPC="docker.io/n4vip/vlessgrpc:latest"

# ===== Protocol Defaults =====
## Trojan
TROJAN_PASS="Nanda"
TROJAN_TAG="N4 GCP Hour Key"
TROJAN_PATH_ESC="%2F%40n4vpn"
TROJAN_SNI="m.googleapis.com"
TROJAN_ENTRY_HOST="m.googleapis.com"
TROJAN_ALPN="http%2F1.1"
TROJAN_FP="randomized"
TROJAN_TYPE="ws"

## VLESS (WS)
VLESS_UUID="0c890000-4733-b20e-067f-fc341bd20000"
VLESS_PATH_ESC="%2FN4VPN"
VLESS_TAG="N4 GCP VLESS"

## VLESS-gRPC
VLESSGRPC_UUID="0c890000-4733-b20e-067f-fc341bd20000"
VLESSGRPC_SERVICE="n4vpnfree-grpc"
VLESSGRPC_MODE="gun"
VLESSGRPC_TAG="GCP-VLESS-GRPC"

# ===== Choose Protocol =====
echo
echo -e "${BOLD}Choose protocol to deploy:${NC}"
echo "  1) Trojan"
echo "  2) VLESS (WebSocket)"
echo "  3) VLESS-gRPC"
read -rp "Enter 1/2/3 [default: 1]: " _opt || true
_opt="${_opt:-1}"

case "$_opt" in
  1) PROTO="trojan";      IMAGE="$IMG_TROJAN" ;;
  2) PROTO="vless";       IMAGE="$IMG_VLESS" ;;
  3) PROTO="vlessgrpc";   IMAGE="$IMG_VLESSGRPC" ;;
  *) PROTO="trojan";      IMAGE="$IMG_TROJAN" ;;
esac

# ===== Ask Service Name =====
read -rp "Enter Cloud Run service name [default: ${SERVICE}]: " _svc || true
SERVICE="${_svc:-$SERVICE}"

# ===== Summary =====
echo -e "\n${CYAN}========================================${NC}"
echo -e "📦 Project : ${PROJECT}"
echo -e "🌍 Region  : ${REGION}"
echo -e "🛠 Service : ${SERVICE}"
echo -e "🔐 Proto   : ${PROTO}"
echo -e "💾 Memory  : ${MEMORY}"
echo -e "⚡ CPU     : ${CPU}"
echo -e "⏱ Timeout : ${TIMEOUT}s"
echo -e "🔌 Port    : ${PORT}"
if [[ "$PROTO" == "trojan" ]]; then
  echo -e "🔑 Password: ${TROJAN_PASS}"
fi
if [[ "$PROTO" == "vless" ]]; then
  echo -e "🆔 UUID    : ${VLESS_UUID}"
  echo -e "↔️  Type    : WS (path=/N4VPN, sni=m.googleapis.com)"
fi
if [[ "$PROTO" == "vlessgrpc" ]]; then
  echo -e "🆔 UUID    : ${VLESSGRPC_UUID}"
  echo -e "🧩 gRPC serviceName: ${VLESSGRPC_SERVICE} (mode=${VLESSGRPC_MODE}, sni=<CloudRunHost>)"
fi
echo -e "${CYAN}========================================${NC}\n"

# ===== Enable APIs & Deploy =====
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

# ===== Build Final URL =====
URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"
HOST="$(echo "$URL" | sed -E 's#^https?://([^/]+)/?.*#\1#')"

echo -e "\n${GREEN}✅ Deployment finished!${NC}"
echo -e "🌐 Service URL: ${BOLD}${CYAN}${URL}${NC}"

# ===== Build Protocol-Specific Connection URL =====
if [[ "$PROTO" == "trojan" ]]; then
  TAG_ENC="${TROJAN_TAG// /%20}"
  URI="trojan://${TROJAN_PASS}@${TROJAN_ENTRY_HOST}:443?path=${TROJAN_PATH_ESC}&security=tls&alpn=${TROJAN_ALPN}&host=${HOST}&fp=${TROJAN_FP}&type=${TROJAN_TYPE}&sni=${TROJAN_SNI}#${TAG_ENC}"

elif [[ "$PROTO" == "vless" ]]; then
  TAG_ENC="${VLESS_TAG// /%20}"
  URI="vless://${VLESS_UUID}@m.googleapis.com:443?path=${VLESS_PATH_ESC}&security=tls&alpn=http%2F1.1&encryption=none&host=${HOST}&fp=randomized&type=ws&sni=m.googleapis.com#${TAG_ENC}"

elif [[ "$PROTO" == "vlessgrpc" ]]; then
  TAG_ENC="${VLESSGRPC_TAG// /%20}"
  URI="vless://${VLESSGRPC_UUID}@m.googleapis.com:443?mode=${VLESSGRPC_MODE}&security=tls&alpn=http%2F1.1&encryption=none&fp=randomized&type=grpc&serviceName=${VLESSGRPC_SERVICE}&sni=${HOST}#${TAG_ENC}"
fi

# ===== Output =====
echo -e "\n🔗 ${BOLD}Connection URL (${PROTO}):${NC}"
echo -e "   ${YELLOW}${URI}${NC}\n"
echo -e "ℹ️ Change only the value after ${BOLD}host=${NC} (or ${BOLD}sni=${NC} for gRPC) if you want to use a custom domain."