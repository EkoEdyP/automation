#!/usr/bin/env bash
# =============================================================
#  install-worker.sh
#  Jalankan di: k3s-app (103.217.144.152) atau
#               k3s-gateway (116.193.191.28)
#
#  Mode: k3s SERVER (join HA cluster, ikut etcd)
#
#  Cara pakai:
#    export K3S_TOKEN="<token dari master>"
#    export NODE_ROLE="app"      # atau "gateway"
#    sudo -E bash install-worker.sh
# =============================================================
set -euo pipefail

# ── Konfigurasi ───────────────────────────────────────────────
MASTER_PUBLIC_IP="103.197.189.7"
K3S_URL="https://${MASTER_PUBLIC_IP}:6443"

K3S_TOKEN="${K3S_TOKEN:-}"
NODE_ROLE="${NODE_ROLE:-}"

# Deteksi IP dengan fallback robust
NODE_IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
[ -z "$NODE_IP" ] && NODE_IP=$(hostname -I | awk '{print $1}')
NODE_PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me \
  || curl -s --max-time 5 api.ipify.org \
  || echo "$NODE_IP")

# ── Validasi ──────────────────────────────────────────────────
if [ -z "$K3S_TOKEN" ]; then
  echo "❌ ERROR: K3S_TOKEN belum di-set!"
  echo "   export K3S_TOKEN=\"<token dari master>\""
  exit 1
fi
if [ "$NODE_ROLE" != "app" ] && [ "$NODE_ROLE" != "gateway" ]; then
  echo "❌ ERROR: NODE_ROLE harus 'app' atau 'gateway'"
  exit 1
fi

# ── Set nama & label berdasarkan role ─────────────────────────
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

echo "================================================"
echo " [WORKER/SERVER] Install k3s – role: $NODE_ROLE"
echo " Node Name  : $NODE_NAME"
echo " Internal IP: $NODE_IP"
echo " Public IP  : $NODE_PUBLIC_IP"
echo " Master     : $K3S_URL"
echo "================================================"

# ── 1. Update sistem ──────────────────────────────────────────
echo "[1/5] Update sistem..."
apt-get update -qq
apt-get install -y -qq curl wget

# ── 2. Cleanup instalasi k3s lama ─────────────────────────────
echo "[2/5] Cleanup instalasi k3s lama..."

# Fix: gunakan path relatif terhadap lokasi script yang sebenarnya,
# bukan BASH_SOURCE yang tidak reliable saat dipanggil dengan sudo -E bash
SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"

if [ -f "$SCRIPT_DIR/uninstall-k3s.sh" ]; then
  echo "  Menjalankan $SCRIPT_DIR/uninstall-k3s.sh..."
  bash "$SCRIPT_DIR/uninstall-k3s.sh"
else
  echo "  uninstall-k3s.sh tidak ditemukan di $SCRIPT_DIR"
  echo "  Fallback inline cleanup..."
  systemctl stop k3s k3s-agent 2>/dev/null || true
  [ -f /usr/local/bin/k3s-killall.sh ]         && bash /usr/local/bin/k3s-killall.sh 2>/dev/null || true
  [ -f /usr/local/bin/k3s-uninstall.sh ]       && bash /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true
  [ -f /usr/local/bin/k3s-agent-uninstall.sh ] && bash /usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || true
  rm -rf /var/lib/rancher /etc/rancher /run/k3s /run/flannel \
         /etc/cni /opt/cni /var/lib/cni
  for iface in flannel.1 cni0; do
    ip link show "$iface" &>/dev/null \
      && { ip link set "$iface" down 2>/dev/null; ip link delete "$iface" 2>/dev/null; } \
      || true
  done
  systemctl daemon-reload
fi
sleep 3

# ── 3. Test koneksi ke master ─────────────────────────────────
echo "[3/5] Tes koneksi ke master ($K3S_URL)..."
if curl -sk --max-time 10 "$K3S_URL" &>/dev/null; then
  echo "  ✅ Master dapat dijangkau"
else
  echo "  ❌ Tidak bisa reach $K3S_URL"
  echo "  Pastikan port 6443 terbuka di Biznet Gio firewall!"
  exit 1
fi

# ── 4. Install k3s sebagai SERVER (join HA cluster) ───────────
echo "[4/5] Installing k3s server (join HA cluster)..."
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
  --tls-san="$NODE_IP" \
  --node-taint="$NODE_TAINT" \
  --node-label="$NODE_LABEL_1" \
  --node-label="$NODE_LABEL_2" \
  --write-kubeconfig-mode=644

# ── 5. Verifikasi ─────────────────────────────────────────────
echo "[5/5] Verifikasi k3s..."
sleep 10
if systemctl is-active k3s &>/dev/null; then
  echo ""
  echo "  ✅ k3s berjalan di $NODE_NAME (server mode)"
  echo "  Label : $NODE_LABEL_1, $NODE_LABEL_2"
  echo "  Taint : $NODE_TAINT"
else
  echo "  ❌ k3s gagal start. Log:"
  journalctl -u k3s -n 30 --no-pager
  echo ""
  echo "  Jika error 'duplicate node name', hapus dari etcd master:"
  echo "  ssh root@$MASTER_PUBLIC_IP"
  echo "  k3s-etcdctl member list"
  echo "  k3s-etcdctl member remove <ID>"
  exit 1
fi

echo ""
echo "================================================"
echo " ✅ $NODE_NAME selesai!"
echo ""
echo "  Verifikasi dari master:"
echo "  ssh root@$MASTER_PUBLIC_IP"
echo "  kubectl get nodes -o wide"
echo "================================================"