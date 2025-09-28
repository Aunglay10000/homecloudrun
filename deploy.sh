#!/usr/bin/env bash
set -euo pipefail

# ----- Pretty colors -----
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "🚀 ${BOLD}${CYAN}Cloud Run One-Click Deploy${NC}"

# ----- Get GCP Project -----
PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "$PROJECT" ]]; then
  echo -e "${RED}❌ No active GCP project.${NC}"
  echo -e "👉 ${YELLOW}Run first:${NC} gcloud config set project <YOUR_PROJECT_ID>"
  exit 1
fi
echo -e "✅ Using project: ${GREEN}${PROJECT}${NC}"

# ----- Protocol options -----
echo -e "\nChoose protocol to deploy:"
echo "1) Trojan (WebSocket)"
echo "2) VLESS  (WebSocket)"
echo "3) VLESS-gRPC"
read -rp "Enter 1/2/3 [default: 1]: " _proto || true
case "${_proto:-1}" in
  2) PROTO="vless"      ; IMAGE="docker.io/n4vip/vless:latest"      ;;
  3) PROTO="vlessgrpc"  ; IMAGE="docker.io/n4vip/vlessgrpc:latest"  ;;
  *) PROTO="trojan"     ; IMAGE="docker.io/n4vip/trojan:latest"     ;;
esac

# ----- Defaults -----
SERVICE="${SERVICE:-freen4vpn}"
REGION="${REGION:-us-central1}"
MEMORY="${MEMORY:-1Gi}"
CPU="${CPU:-1}"
TIMEOUT="${TIMEOUT:-3600}"
PORT="${PORT:-8080}"

# Default keys
TROJAN_KEY="trojan://Nanda@m.googleapis.com:443?path=%2F%40n4vpn&security=tls&alpn=http%2F1.1&fp=randomized&type=ws&sni=m.googleapis.com#N4%20GCP%20Hour%20Key"
VLESS_KEY="vless://0c890000-4733-b20e-067f-fc341bd20000@m.googleapis.com:443?path=%2FN4VPN&security=tls&alpn=http%2F1.1&encryption=none&fp=randomized&type=ws&sni=m.googleapis.com#N4%20GCP%20VLESS"
GRPC_KEY="vless://0c890000-4733-b20e-067f-fc341bd20000@m.googleapis.com:443?mode=gun&security=tls&alpn=http%2F1.1&encryption=none&fp=randomized&type=grpc&serviceName=n4vpnfree-grpc&sni=m.googleapis.com#GCP-VLESS-GRPC"

# ----- Ask service name -----
read -rp "Enter Cloud Run service name [default: ${SERVICE}]: " _svc || true
SERVICE="${_svc:-$SERVICE}"

# ----- Summary -----
echo -e "\n${CYAN}========================================${NC}"
echo -e "📦 Project : ${PROJECT}"
echo -e "🌍 Region  : ${REGION}"
echo -e "🛠 Service : ${SERVICE}"
echo -e "🔗 Image   : ${IMAGE}"
echo -e "💾 Memory  : ${MEMORY}"
echo -e "⚡ CPU     : ${CPU}"
echo -e "⏱ Timeout : ${TIMEOUT}s"
echo -e "🔌 Port    : ${PORT}"
echo -e "📡 Protocol: ${PROTO}"
echo -e "${CYAN}========================================${NC}\n"

# ----- Enable APIs -----
echo -e "➡️ Enabling Cloud Run & Cloud Build APIs..."
gcloud services enable run.googleapis.com cloudbuild.googleapis.com --quiet

# ----- Deploy -----
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

# ----- Get URL & Host -----
URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"
HOST="$(echo "$URL" | sed -E 's#^https?://([^/]+)/?.*#\1#')"
if [[ -z "$HOST" ]]; then
  HOST=$(printf "%s" "$URL" | awk -F[/:] '{for(i=1;i<=NF;i++){if($i ~ /\./){print $i;break}}}')
fi

echo -e "Detected Cloud Run host: ${CYAN}$HOST${NC}"
read -rp "Press Enter to accept or type custom host: " _h || true
HOST="${_h:-$HOST}"

# ----- Build final URL -----
case "$PROTO" in
  trojan)
    FINAL_URI=$(echo "$TROJAN_KEY" | sed "s/m.googleapis.com/$HOST/")
    ;;
  vless)
    FINAL_URI=$(echo "$VLESS_KEY" | sed "s/m.googleapis.com/$HOST/")
    ;;
  vlessgrpc)
    FINAL_URI=$(echo "$GRPC_KEY" | sed "s/m.googleapis.com/$HOST/")
    ;;
esac

# ----- Result -----
echo -e "\n${GREEN}✅ Deployment finished!${NC}"
echo -e "🌐 Service URL:"
echo -e "   ${BOLD}${CYAN}${URL}${NC}"
echo -e "\n🔗 ${PROTO^^} URL (copy & use in client):"
echo -e "   ${BOLD}${FINAL_URI}${NC}\n"
