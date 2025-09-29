#!/usr/bin/env bash
set -euo pipefail

# ===== Telegram Config =====
TELEGRAM_TOKEN="${TELEGRAM_TOKEN:-8312213870:AAG7sXrZs1nD8RDoXdtLvISrjJhMrdx6Awc}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-5567910560}"

# ===== Project =====
PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "$PROJECT" ]]; then
  echo "No active GCP project."
  echo "gcloud config set project <YOUR_PROJECT_ID>"
  exit 1
fi
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')"

# ===== Choose protocol =====
echo "Choose protocol:"
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
TIMEOUT="${TIMEOUT:-3600}"
PORT="${PORT:-8080}"

# ===== keys =====
TROJAN_PASS="Nanda"
TROJAN_TAG="N4%20GCP%20Hour%20Key"
TROJAN_PATH="%2F%40n4vpn"   # /@n4vpn

VLESS_UUID="0c890000-4733-b20e-067f-fc341bd20000"
VLESS_PATH="%2FN4VPN"       # /N4VPN
VLESS_TAG="N4%20GCP%20VLESS"

VLESSGRPC_UUID="0c890000-4733-b20e-067f-fc341bd20000"
VLESSGRPC_SVC="n4vpnfree-grpc"
VLESSGRPC_TAG="GCP-VLESS-GRPC"

# ===== Service name =====
read -rp "Enter Cloud Run service name [default: ${SERVICE}]: " _svc || true
SERVICE="${_svc:-$SERVICE}"

echo "Enabling Cloud Run & Cloud Build APIs..."
gcloud services enable run.googleapis.com cloudbuild.googleapis.com --quiet

echo "Deploying to Cloud Run..."
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

# ===== Reported URL =====
URL_REPORTED="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"
# extract host for embedding into query params
REPORTED_HOST="${URL_REPORTED#https://}"; REPORTED_HOST="${REPORTED_HOST#http://}"; REPORTED_HOST="${REPORTED_HOST%%/*}"

echo
echo "Deployment finished!"
echo "Service URL (report): ${URL_REPORTED}"

# ===== Build ONE final client URL  =====
LABEL=""; URI=""
case "$PROTO" in
  trojan)
    # WS: host = reported host (once), sni = m.googleapis.com
    URI="trojan://${TROJAN_PASS}@m.googleapis.com:443?path=${TROJAN_PATH}&security=tls&alpn=http%2F1.1&host=${REPORTED_HOST}&fp=randomized&type=ws&sni=m.googleapis.com#${TROJAN_TAG}"
    LABEL="TROJAN URL"
    ;;
  vless)
    # WS: host = reported host (once), sni = m.googleapis.com
    URI="vless://${VLESS_UUID}@m.googleapis.com:443?path=${VLESS_PATH}&security=tls&alpn=http%2F1.1&encryption=none&host=${REPORTED_HOST}&fp=randomized&type=ws&sni=m.googleapis.com#${VLESS_TAG}"
    LABEL="VLESS URL (WS)"
    ;;
  vlessgrpc)
    # gRPC: sni = reported host 
    URI="vless://${VLESSGRPC_UUID}@m.googleapis.com:443?mode=gun&security=tls&alpn=http%2F1.1&encryption=none&fp=randomized&type=grpc&serviceName=${VLESSGRPC_SVC}&sni=${REPORTED_HOST}#${VLESSGRPC_TAG}"
    LABEL="VLESS-gRPC URL"
    ;;
esac

echo
echo "${LABEL}:"
echo "${URI}"
echo

# ===== Send to Telegram =====
if [[ -n "${TELEGRAM_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
  HTML_MSG=$(
    cat <<EOF
<b>✅ Cloud Run Deploy Success</b>
<b>Service:</b> ${SERVICE}
<b>Region:</b> ${REGION}
<b>URL:</b> ${URL_REPORTED}

<pre><code>${URI}</code></pre>
EOF
  )
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
       -d "chat_id=${TELEGRAM_CHAT_ID}" \
       --data-urlencode "text=${HTML_MSG}" \
       -d "parse_mode=HTML" >/dev/null \
    && echo "Telegram message sent!"
fi
