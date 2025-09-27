#!/usr/bin/env bash
set -euo pipefail

echo "🚀 CloudRun Free One Click By Nanda "

# --- လက်ရှိ Cloud Shell / gcloud config ထဲက Project ကိုယူ ---
PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "$PROJECT" ]]; then
  echo "❌ လက်ရှိအသုံးပြုနေသော GCP Project မတွေ့ပါ။"
  echo "👉 ပထမဆုံး ဒီ Commend ကို run လုပ်ပေးပါ: gcloud config set project <သင့်ProjectID>"
  exit 1
fi
echo "✅ လက်ရှိသုံးနေသော GCP Project: $PROJECT"

# --- Service Name ကို မေး ---
read -rp "Deploy လုပ်မည့် Service အမည် (မထည့်ရင် default: freen4vpn): " SERVICE
SERVICE="${SERVICE:-freen4vpn}"

# --- နဂို သတ်မှတ်ထားသော Setting များ ---
REGION="us-central1"                        # Deploy ချင်တဲ့ Region
IMAGE="docker.io/n4vip/trojan:latest"       # သုံးမည့် Docker Image
MEMORY="1Gi"                                # Memory
CPU="1"                                     # CPU
TIMEOUT="3600"                              # Timeout (စက္ကန့်)
PORT="8080"                                 # Container Port

# --- Deploy မလုပ်ခင် အကြို ပြသ ---
echo
echo "=============================="
echo "🚀 Deploy လုပ်မည့် အချက်အလက်များ"
echo "=============================="
echo "Project   : $PROJECT"
echo "Region    : $REGION"
echo "Service   : $SERVICE"
echo "Image     : $IMAGE"
echo "Memory    : $MEMORY"
echo "CPU       : $CPU"
echo "Timeout   : $TIMEOUT စက္ကန့်"
echo "Port      : $PORT"
echo "=============================="
echo

read -rp "ဤအချက်အလက်များနဲ့ Deploy လုပ်မလား? (y/n): " GO
[[ "$GO" =~ ^[Yy]$ ]] || { echo "🚫 Deploy ကို ရပ်လိုက်ပါသည်။"; exit 0; }

# --- API များ ဖွင့်ရန် ---
echo "➡️ Cloud Run နှင့် Cloud Build API များ ဖွင့်နေပါသည်..."
gcloud services enable run.googleapis.com cloudbuild.googleapis.com

# --- Deploy စတင် ---
echo "➡️ Cloud Run သို့ Deploy လုပ်နေသည်..."
gcloud run deploy "$SERVICE" \
  --image="$IMAGE" \
  --platform=managed \
  --region="$REGION" \
  --memory="$MEMORY" \
  --cpu="$CPU" \
  --timeout="$TIMEOUT" \
  --allow-unauthenticated \
  --port="$PORT"

# --- URL ပြသ ---
URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"
echo
echo "🎉 Deploy ပြီးပါပြီ ✅"
echo "🌐 သင့် Service URL: $URL"
