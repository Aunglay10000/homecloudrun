#!/usr/bin/env bash
set -euo pipefail

# ---------- Colors ----------
GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
echo -e "🚀 ${BOLD}${CYAN}Cloud Run Deploy (QR with N4 VPN Logo)${NC}"

# ---------- GCP ----------
PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "$PROJECT" ]]; then
  echo -e "${RED}❌ No active GCP project.${NC}"
  echo -e "👉 Run: ${YELLOW}gcloud config set project <YOUR_PROJECT_ID>${NC}"
  exit 1
fi
echo -e "✅ ${GREEN}Current Project:${NC} $PROJECT"

# ---------- Inputs ----------
SERVICE="${SERVICE:-freen4vpn}"
REGION="${REGION:-us-central1}"
IMAGE="${IMAGE:-docker.io/n4vip/trojan:latest}"
MEMORY="${MEMORY:-1Gi}"
CPU="${CPU:-1}"
TIMEOUT="${TIMEOUT:-3600}"
PORT="${PORT:-8080}"

TROJAN_PASS="${TROJAN_PASS:-Nanda}"
TROJAN_TAG="${TROJAN_TAG:-N4 GCP Hour Key}"
TROJAN_PATH_ESC="%2F%40n4vpn"
TROJAN_SNI="m.googleapis.com"
TROJAN_ENTRY_HOST="m.googleapis.com"
TROJAN_ALPN="http%2F1.1"
TROJAN_FP="randomized"
TROJAN_TYPE="ws"

read -rp "Enter Cloud Run service name [default: ${SERVICE}]: " _inp || true
SERVICE="${_inp:-$SERVICE}"

# ---------- Summary ----------
echo -e "\n${CYAN}===============================${NC}"
echo -e "⚙️  Deploy Settings"
echo -e "${CYAN}===============================${NC}"
echo -e "📦 Project : ${GREEN}$PROJECT${NC}"
echo -e "🌍 Region  : ${GREEN}$REGION${NC}"
echo -e "🛠 Service : ${GREEN}$SERVICE${NC}"
echo -e "💾 Memory  : ${GREEN}$MEMORY${NC}"
echo -e "⚡ CPU     : ${GREEN}$CPU${NC}"
echo -e "⏱ Timeout : ${GREEN}${TIMEOUT}s${NC}"
echo -e "🔌 Port    : ${GREEN}$PORT${NC}"
echo -e "${CYAN}===============================${NC}\n"

read -rp "Proceed? (y/n): " GO || true
[[ "$GO" =~ ^[Yy]$ ]] || { echo -e "${RED}🚫 Cancelled.${NC}"; exit 0; }

# ---------- Enable APIs ----------
gcloud services enable run.googleapis.com cloudbuild.googleapis.com --quiet

# ---------- Deploy ----------
echo -e "➡️ ${CYAN}Deploying...${NC}"
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

# ---------- Build Trojan URI ----------
URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"
HOST="$(echo "$URL" | sed -E 's#^https?://([^/]+)/?.*#\1#')"

TAG_ENC="${TROJAN_TAG// /%20}"
TROJAN_URI="trojan://${TROJAN_PASS}@${TROJAN_ENTRY_HOST}:443?path=${TROJAN_PATH_ESC}&security=tls&alpn=${TROJAN_ALPN}&host=${HOST}&fp=${TROJAN_FP}&type=${TROJAN_TYPE}&sni=${TROJAN_SNI}#${TAG_ENC}"

TXT_FILE="trojan_${SERVICE}.txt"
PNG_FILE="trojan_${SERVICE}.png"
echo -n "${TROJAN_URI}" > "${TXT_FILE}"

echo -e "\n${GREEN}✅ Deployed!${NC}"
echo -e "🌐 Service URL: ${CYAN}${URL}${NC}"
echo -e "🔗 Trojan URI: ${YELLOW}${TROJAN_URI}${NC}"

# ---------- QR + Logo ----------
echo -e "➡️ ${CYAN}Generating QR with N4 VPN Logo...${NC}"
python3 - <<'PY' "${TROJAN_URI}" "${PNG_FILE}"
import sys
data = sys.argv[1]
png = sys.argv[2]
try:
    import qrcode
    from PIL import Image
    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_H)
    qr.add_data(data)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white").convert('RGB')
    # Insert logo
    try:
        logo = Image.open("n4logo.png")  # <- logo name ပြောင်းထား
        size = img.size[0]//4
        logo = logo.resize((size, size))
        pos = ((img.size[0]-logo.size[0])//2, (img.size[1]-logo.size[1])//2)
        img.paste(logo, pos, mask=logo if logo.mode=="RGBA" else None)
    except Exception as e:
        print("⚠️ Logo not found or failed:", e)
    img.save(png)
    print("QR_OK")
except Exception as e:
    print("QR_ERR", e)
PY

if [[ -f "${PNG_FILE}" ]]; then
  echo -e "🖼  QR PNG created: ${YELLOW}${PNG_FILE}${NC}"
else
  echo -e "${RED}⚠️ QR PNG failed. Showing ASCII QR instead.${NC}"
  python3 - <<'PY' "${TROJAN_URI}"
import sys, qrcode
data=sys.argv[1]
qr=qrcode.QRCode(border=1, box_size=1); qr.add_data(data); qr.make(fit=True)
for r in qr.get_matrix(): print(''.join('██' if c else '  ' for c in r))
PY
fi

# ---------- Auto Download (Cloud Shell) ----------
if command -v cloudshell >/dev/null 2>&1; then
  cloudshell download "${TXT_FILE}" || true
  [[ -f "${PNG_FILE}" ]] && cloudshell download "${PNG_FILE}" || true
  echo -e "💡 Allow pop-ups/downloads for shell.cloud.google.com if dialog doesn’t show."
else
  echo -e "${YELLOW}ℹ️ No cloudshell helper. Download manually from editor.${NC}"
fi
