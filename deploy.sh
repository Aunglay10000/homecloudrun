#!/usr/bin/env bash
set -euo pipefail

# =============== Pretty Colors ===============
GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
echo -e "🚀 ${BOLD}${CYAN}Cloud Run One-Click Deploy (QR + n4logo.png)${NC}"

# =============== GCP Project ===============
PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "$PROJECT" ]]; then
  echo -e "${RED}❌ No active GCP project.${NC}"
  echo -e "👉 Run first: ${YELLOW}gcloud config set project <YOUR_PROJECT_ID>${NC}"
  exit 1
fi
echo -e "✅ ${GREEN}Project:${NC} ${PROJECT}"

# =============== Inputs (can override via env) ===============
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
TROJAN_PATH_ESC="%2F%40n4vpn"
TROJAN_SNI="m.googleapis.com"
TROJAN_ENTRY_HOST="m.googleapis.com"
TROJAN_ALPN="http%2F1.1"
TROJAN_FP="randomized"
TROJAN_TYPE="ws"

# =============== Ask only service name (no confirm step) ===============
read -rp "Enter Cloud Run service name [default: ${SERVICE}]: " _inp || true
SERVICE="${_inp:-$SERVICE}"

# =============== Show plan (info only) ===============
echo -e "\n${CYAN}========================================${NC}"
echo -e "⚙️  ${BOLD}Deploy Settings${NC}"
echo -e "📦 Project : ${GREEN}$PROJECT${NC}"
echo -e "🌍 Region  : ${GREEN}$REGION${NC}"
echo -e "🛠 Service : ${GREEN}$SERVICE${NC}"
echo -e "💾 Memory  : ${GREEN}$MEMORY${NC}"
echo -e "⚡ CPU     : ${GREEN}$CPU${NC}"
echo -e "⏱ Timeout : ${GREEN}${TIMEOUT}s${NC}"
echo -e "🔌 Port    : ${GREEN}$PORT${NC}"
echo -e "${CYAN}========================================${NC}\n"

# =============== Enable APIs & Deploy (no y/n) ===============
echo -e "➡️ ${CYAN}Enabling Cloud Run & Cloud Build APIs...${NC}"
gcloud services enable run.googleapis.com cloudbuild.googleapis.com --quiet

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

# =============== Collect URL & Build Trojan URI ===============
URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"
HOST="$(echo "$URL" | sed -E 's#^https?://([^/]+)/?.*#\1#')"

TAG_ENC="${TROJAN_TAG// /%20}"
TROJAN_URI="trojan://${TROJAN_PASS}@${TROJAN_ENTRY_HOST}:443?path=${TROJAN_PATH_ESC}&security=tls&alpn=${TROJAN_ALPN}&host=${HOST}&fp=${TROJAN_FP}&type=${TROJAN_TYPE}&sni=${TROJAN_SNI}#${TAG_ENC}"

TXT_FILE="trojan_${SERVICE}.txt"
PNG_FILE="trojan_${SERVICE}.png"
echo -n "${TROJAN_URI}" > "${TXT_FILE}"

echo -e "\n${GREEN}✅ Deployment finished!${NC}"
echo -e "🌐 Service URL: ${BOLD}${CYAN}${URL}${NC}"
echo -e "🔗 Trojan URI : ${YELLOW}${TROJAN_URI}${NC}"

# =============== Install QR deps automatically ===============
echo -e "➡️ ${CYAN}Preparing QR dependencies (qrcode + Pillow)...${NC}"
python3 -m pip show qrcode >/dev/null 2>&1 || python3 -m pip install --user "qrcode[pil]" --quiet || true

# =============== Generate QR with center logo n4logo.png ===============
echo -e "➡️ ${CYAN}Generating QR (with n4logo.png if present)...${NC}"
python3 - "$TROJAN_URI" "$PNG_FILE" <<'PY'
import sys
data, out_png = sys.argv[1], sys.argv[2]
try:
    import qrcode
    from PIL import Image
    # High error correction (keeps QR scannable with logo)
    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_H, border=2)
    qr.add_data(data); qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white").convert("RGBA")

    try:
        logo = Image.open("n4logo.png")  # logo name fixed
        # Resize logo to ~25% of QR width
        size = img.size[0] // 4
        logo = logo.convert("RGBA").resize((size, size))
        # Paste centered
        pos = ((img.size[0]-size)//2, (img.size[1]-size)//2)
        img.alpha_composite(logo, dest=pos)
    except Exception as e:
        # No logo or failed → continue with plain QR
        print("⚠️ Logo not used:", e)

    img.convert("RGB").save(out_png)
    print("QR_OK")
except Exception as e:
    print("QR_ERR", e)
    sys.exit(1)
PY

if [[ -f "${PNG_FILE}" ]]; then
  echo -e "🖼  QR PNG saved: ${YELLOW}${PNG_FILE}${NC}"
else
  echo -e "${RED}⚠️ QR PNG failed. Printing ASCII QR on screen...${NC}"
  python3 - "$TROJAN_URI" <<'PY' || true
import sys, qrcode
data=sys.argv[1]
qr=qrcode.QRCode(border=1, box_size=1); qr.add_data(data); qr.make(fit=True)
for r in qr.get_matrix(): print(''.join('██' if c else '  ' for c in r))
PY
fi

# =============== Auto Download (Cloud Shell helper) ===============
if command -v cloudshell >/dev/null 2>&1; then
  cloudshell download "${TXT_FILE}" || true
  [[ -f "${PNG_FILE}" ]] && cloudshell download "${PNG_FILE}" || true
  echo -e "💡 If no dialog shows: allow Pop-ups & Automatic downloads for shell.cloud.google.com, then run:"
  echo -e "   cloudshell download ${TXT_FILE}"
  [[ -f "${PNG_FILE}" ]] && echo -e "   cloudshell download ${PNG_FILE}"
else
  echo -e "${YELLOW}ℹ️ 'cloudshell' helper not found. Download from the editor sidebar manually.${NC}"
fi

# =============== Final echo ===============
echo -e "\n🔗 Trojan URI:"
echo -e "${BOLD}${TROJAN_URI}${NC}\n"
