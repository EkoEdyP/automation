#!/usr/bin/env bash
set -euo pipefail

# ── Konfigurasi ───────────────────────────────────────────────
MASTER_PUBLIC_IP="103.197.189.7"
K3S_URL="https://${MASTER_PUBLIC_IP}:6443"

K3S_TOKEN="${K3S_TOKEN:-}"
NODE_ROLE="${NODE_ROLE:-}"

# ── Deteksi IP ────────────────────────────────────────────────
NODE_IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
[ -z "$NODE_IP" ] && NODE_IP=$(hostname -I | awk '{print $1}')

NODE_PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me \
  || curl -s --max-time 5 api.ipify.org \
  || echo "$NODE_IP")

# ── Validasi ──────────────────────────────────────────────────
if [ -z "$K3S_TOKEN" ]; then
  echo "❌ ERROR: K3S_TOKEN belum di-set!"
  exit 1
fi

if [[ "$NODE_ROLE" != "app" && "$NODE_ROLE" != "gateway" ]]; then
  echo "❌ ERROR: NODE_ROLE harus 'app' atau 'gateway'"
  exit 1
fi

# ── Static hostname ───────────────────────────────────────────
if [ "$NODE_ROLE" = "gateway" ]; then
  NODE_NAME="k3s-gateway"
  NODE_LABEL_1="node-role=gateway"
  NODE_LABEL_2="ingress-ready=true"
  NODE_TAINT="workload=gateway:NoSchedule"
else
  NODE_NAME="k3s-app"
  NODE_LABEL_1="node-role=app"
  NODE_LABEL_2="app-ready=true"
  NODE_TAINT="workload=app:NoSchedule"
fi

# ── ENFORCE hostname (FIX penting) ────────────────────────────
CURRENT_HOSTNAME=$(hostname)

if [ "$CURRENT_HOSTNAME" != "$NODE_NAME" ]; then
  echo "[Fix hostname] $CURRENT_HOSTNAME → $NODE_NAME"
  hostnamectl set-hostname "$NODE_NAME"
  echo "$NODE_NAME" > /etc/hostname
fi

# ── Info ─────────────────────────────────────────────────────
echo "================================================"
echo " Install k3s SERVER – role: $NODE_ROLE"
echo " Hostname   : $(hostname)"
echo " Node Name  : $NODE_NAME"
echo " Internal IP: $NODE_IP"
echo " Public IP  : $NODE_PUBLIC_IP"
echo " Master     : $K3S_URL"
echo "================================================"

# ── 1. Update ────────────────────────────────────────────────
echo "[1/5] Update sistem..."
apt-get update -qq
apt-get install -y -qq curl wget

# ── 2. Cleanup (pakai script kamu) ────────────────────────────
echo "[2/5] Cleanup k3s lama..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f "$SCRIPT_DIR/uninstall-k3s.sh" ]; then
  echo "  ▶ Menjalankan uninstall-k3s.sh"
  bash "$SCRIPT_DIR/uninstall-k3s.sh"
else
  echo "  ⚠ uninstall-k3s.sh tidak ditemukan, fallback..."
  /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true
  /usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || true
  rm -rf /var/lib/rancher/k3s /etc/rancher /var/lib/cni
fi

sleep 3

# ── 3. Test koneksi ──────────────────────────────────────────
echo "[3/5] Tes koneksi ke master..."
if curl -sk --max-time 10 "$K3S_URL" &>/dev/null; then
  echo "  ✅ Master reachable"
else
  echo "  ❌ Tidak bisa reach $K3S_URL"
  echo "  Cek firewall port 6443!"
  exit 1
fi

# ── 4. Install k3s (FIX advertise IP) ────────────────────────
echo "[4/5] Install k3s server (join HA cluster)..."

curl -sfL https://get.k3s.io | sh -s - server \
  --server="$K3S_URL" \
  --token="$K3S_TOKEN" \
  --node-name="$NODE_NAME" \
  --node-ip="$NODE_IP" \
  --node-external-ip="$NODE_PUBLIC_IP" \
  --bind-address="$NODE_IP" \
  --advertise-address="$NODE_IP" \
  --tls-san="$NODE_PUBLIC_IP" \
  --tls-san="$NODE_IP" \
  --disable=traefik \
  --disable=servicelb \
  --node-taint="$NODE_TAINT" \
  --node-label="$NODE_LABEL_1" \
  --node-label="$NODE_LABEL_2" \
  --write-kubeconfig-mode=644

# ── 5. Verifikasi ────────────────────────────────────────────
echo "[5/5] Verifikasi..."
sleep 10

if systemctl is-active k3s &>/dev/null; then
  echo ""
  echo "  ✅ k3s berjalan di $NODE_NAME"
  echo "  Label : $NODE_LABEL_1, $NODE_LABEL_2"
  echo "  Taint : $NODE_TAINT"
else
  echo "  ❌ k3s gagal start"
  journalctl -u k3s -n 50 --no-pager
  exit 1
fi

echo ""
echo "================================================"
echo " ✅ $NODE_NAME selesai!"
echo "  Cek dari master: kubectl get nodes -o wide"
echo "================================================"