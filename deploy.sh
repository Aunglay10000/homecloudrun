#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
echo -e "🚀 ${BOLD}${CYAN}Cloud Run One-Click Deploy (Trojan / VLESS / VLESS-gRPC)${NC}"

# Project
PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
[[ -z "$PROJECT" ]] && { echo "❌ No active GCP project."; echo "👉 gcloud config set project <YOUR_PROJECT_ID>"; exit 1; }
echo -e "✅ Using project: ${GREEN}${PROJECT}${NC}"

# Choose proto
echo; echo -e "${BOLD}Choose protocol:${NC}"
echo "  1) Trojan (WS)"; echo "  2) VLESS (WS)"; echo "  3) VLESS (gRPC)"
read -rp "Enter 1/2/3 [default: 1]: " _opt || true
case "${_opt:-1}" in
  2) PROTO="vless"     ; IMAGE="docker.io/n4vip/vless:latest"     ;;
  3) PROTO="vlessgrpc" ; IMAGE="docker.io/n4vip/vlessgrpc:latest" ;;
  *) PROTO="trojan"    ; IMAGE="docker.io/n4vip/trojan:latest"    ;;
esac

# Defaults
SERVICE="${SERVICE:-freen4vpn}"
REGION="${REGION:-us-central1}"
MEMORY="${MEMORY:-1Gi}"; CPU="${CPU:-1}"
TIMEOUT="${TIMEOUT:-3600}"; PORT="${PORT:-8080}"

# Fixed keys (host/sni ကို script က auto ထည့်မယ်)
TROJAN_PASS="Nanda"; TROJAN_TAG="N4%20GCP%20Hour%20Key"; TROJAN_PATH="%2F%40n4vpn"
VLESS_UUID="0c890000-4733-b20e-067f-fc341bd20000"; VLESS_PATH="%2FN4VPN"; VLESS_TAG="N4%20GCP%20VLESS"
VLESSGRPC_UUID="0c890000-4733-b20e-067f-fc341bd20000"; VLESSGRPC_SVC="n4vpnfree-grpc"; VLESSGRPC_TAG="GCP-VLESS-GRPC"

# Service name
read -rp "Enter Cloud Run service name [default: ${SERVICE}]: " _svc || true
SERVICE="${_svc:-$SERVICE}"

# Summary (Docker image မပြ)
echo -e "\n${CYAN}========================================${NC}"
echo -e "📦 Project : ${PROJECT}"
echo -e "🌍 Region  : ${REGION}"
echo -e "🛠 Service : ${SERVICE}"
echo -e "📡 Protocol: ${PROTO}"
echo -e "💾 Memory  : ${MEMORY}   ⚡ CPU: ${CPU}"
echo -e "⏱ Timeout : ${TIMEOUT}s  🔌 Port: ${PORT}"
echo -e "${CYAN}========================================${NC}\n"

# Enable & Deploy
echo -e "➡️ Enabling Cloud Run & Cloud Build APIs..."
gcloud services enable run.googleapis.com cloudbuild.googleapis.com --quiet
echo -e "➡️ Deploying to Cloud Run..."
gcloud run deploy "$SERVICE" \
  --image="$IMAGE" --platform=managed --region="$REGION" \
  --memory="$MEMORY" --cpu="$CPU" --timeout="$TIMEOUT" \
  --allow-unauthenticated --port="$PORT" --quiet

# Exact URL & host
URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"
HOST="$(echo "$URL" | sed -E 's#^https?://([^/]+)/?.*#\1#')"
[[ -z "$HOST" ]] && HOST=$(printf "%s" "$URL" | awk -F[/:] '{for(i=1;i<=NF;i++){if($i ~ /\./){print $i;break}}}')

echo -e "\n${GREEN}✅ Deployment finished!${NC}"
echo -e "🌐 Service URL: ${BOLD}${CYAN}${URL}${NC}"

# Build final client URL (HOST/SNI auto inject)
case "$PROTO" in
  trojan)
    URI="trojan://${TROJAN_PASS}@m.googleapis.com:443?path=${TROJAN_PATH}&security=tls&alpn=http%2F1.1&host=${HOST}&fp=randomized&type=ws&sni=m.googleapis.com#${TROJAN_TAG}"
    LABEL="TROJAN URL"
    ;;
  vless)
    URI="vless://${VLESS_UUID}@m.googleapis.com:443?path=${VLESS_PATH}&security=tls&alpn=http%2F1.1&encryption=none&host=${HOST}&fp=randomized&type=ws&sni=m.googleapis.com#${VLESS_TAG}"
    LABEL="VLESS URL (WS)"
    ;;
  vlessgrpc)
    URI="vless://${VLESSGRPC_UUID}@m.googleapis.com:443?mode=gun&security=tls&alpn=http%2F1.1&encryption=none&fp=randomized&type=grpc&serviceName=${VLESSGRPC_SVC}&sni=${HOST}#${VLESSGRPC_TAG}"
    LABEL="VLESS-gRPC URL"
    ;;
esac

echo -e "\n🔗 ${BOLD}${LABEL}:${NC}"
echo -e "   ${YELLOW}${URI}${NC}\n"
