#!/usr/bin/env bash
# =============================================================
#  install-worker.sh
#  Jalankan di: k3s-app ATAU k3s-gateway (IDCloudHost)
#
#  Cara pakai:
#    ssh user@<ip-worker>
#    export K3S_TOKEN="<token dari master>"
#    export NODE_ROLE="app"      # atau "gateway"
#    chmod +x install-worker.sh && sudo -E bash install-worker.sh
#
#  Contoh untuk k3s-app:
#    export K3S_TOKEN="K10xxx...::server:xxx"
#    export NODE_ROLE="app"
#    sudo -E bash install-worker.sh
#
#  Contoh untuk k3s-gateway:
#    export K3S_TOKEN="K10xxx...::server:xxx"
#    export NODE_ROLE="gateway"
#    sudo -E bash install-worker.sh
# =============================================================
set -euo pipefail

# ── Konfigurasi ───────────────────────────────────────────────
MASTER_PUBLIC_IP="103.197.189.7"
K3S_URL="https://${MASTER_PUBLIC_IP}:6443"

# Ambil dari environment variable
K3S_TOKEN="${K3S_TOKEN:-}"
NODE_ROLE="${NODE_ROLE:-}"

# Deteksi IP internal node ini
NODE_IP=$(ip route get 1 | awk '{print $7; exit}')
NODE_PUBLIC_IP=$(curl -s ifconfig.me || curl -s api.ipify.org)

# ── Validasi input ────────────────────────────────────────────
if [ -z "$K3S_TOKEN" ]; then
  echo "❌ ERROR: K3S_TOKEN belum di-set!"
  echo "   export K3S_TOKEN=\"<token dari master>\""
  exit 1
fi

if [ "$NODE_ROLE" != "app" ] && [ "$NODE_ROLE" != "gateway" ]; then
  echo "❌ ERROR: NODE_ROLE harus 'app' atau 'gateway'"
  echo "   export NODE_ROLE=\"app\"   atau"
  echo "   export NODE_ROLE=\"gateway\""
  exit 1
fi

# ── Set nama node & taint berdasarkan role ────────────────────
if [ "$NODE_ROLE" = "gateway" ]; then
  NODE_NAME="k3s-gateway"
  NODE_TAINT="workload=gateway:NoSchedule"
  NODE_LABEL="node-role=gateway"
  EXTRA_LABEL="ingress-ready=true"
else
  NODE_NAME="k3s-app"
  NODE_TAINT="workload=app:NoSchedule"
  NODE_LABEL="node-role=app"
  EXTRA_LABEL="app-ready=true"
fi

echo "================================================"
echo " [WORKER] Install k3s – role: $NODE_ROLE"
echo " Node Name  : $NODE_NAME"
echo " Internal IP: $NODE_IP"
echo " Public IP  : $NODE_PUBLIC_IP"
echo " Master     : $K3S_URL"
echo "================================================"

# ── 1. Update sistem ──────────────────────────────────────────
echo "[1/4] Update sistem..."
apt-get update -qq
apt-get install -y -qq curl wget

# ── 2. Test koneksi ke master ─────────────────────────────────
echo "[2/4] Tes koneksi ke master..."
if curl -sk --max-time 10 "$K3S_URL/ping" | grep -q "pong" 2>/dev/null || \
   curl -sk --max-time 10 "$K3S_URL" &>/dev/null; then
  echo "  ✅ Master dapat dijangkau"
else
  echo "  ⚠️  Koneksi ke master mungkin gagal."
  echo "  Pastikan port 6443 terbuka di Biznet Gio firewall!"
  echo "  Melanjutkan instalasi..."
fi

# ── 3. Install k3s sebagai server (join cluster) ──────────────
echo "[3/4] Installing k3s worker (join mode)..."
curl -sfL https://get.k3s.io | sh -s - server \
  --server="$K3S_URL" \
  --token="$K3S_TOKEN" \
  --bind-address="$NODE_IP" \
  --advertise-address="$NODE_PUBLIC_IP" \
  --node-ip="$NODE_IP" \
  --node-external-ip="$NODE_PUBLIC_IP" \
  --node-name="$NODE_NAME" \
  --disable=traefik \
  --disable=servicelb \
  --tls-san="$NODE_PUBLIC_IP" \
  --node-taint="$NODE_TAINT" \
  --node-label="$NODE_LABEL" \
  --node-label="$EXTRA_LABEL"

# ── 4. Verifikasi ─────────────────────────────────────────────
echo "[4/4] Verifikasi k3s..."
sleep 8
if systemctl is-active k3s &>/dev/null; then
  echo ""
  echo "  ✅ k3s berjalan di $NODE_NAME"
  echo "  Label  : $NODE_LABEL, $EXTRA_LABEL"
  echo "  Taint  : $NODE_TAINT"
else
  echo "  ⚠️  k3s belum aktif:"
  journalctl -u k3s -n 20 --no-pager || true
fi

echo ""
echo "================================================"
echo " ✅ $NODE_NAME selesai!"
echo ""
echo "  Verifikasi dari master:"
echo "  ssh user@103.197.189.7"
echo "  kubectl get nodes -o wide"
echo ""
if [ "$NODE_ROLE" = "gateway" ]; then
  echo "  Firewall yang perlu dibuka di node ini:"
  echo "  - TCP 80   → HTTP ingress"
  echo "  - TCP 443  → HTTPS ingress"
  echo "  - TCP 8080 → Traefik dashboard"
  echo "  - UDP 8472 → Flannel VXLAN (antar node)"
else
  echo "  Firewall yang perlu dibuka di node ini:"
  echo "  - UDP 8472 → Flannel VXLAN (antar node)"
  echo "  - TCP 10250 → Kubelet"
fi
echo "================================================"