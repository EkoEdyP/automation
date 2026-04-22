#!/usr/bin/env bash
# =============================================================
#  install-master.sh
#  Jalankan di: k3s-master (Biznet Gio)
#  IP Public  : 103.197.189.7
#
#  Cara pakai:
#    ssh user@103.197.189.7
#    chmod +x install-master.sh && sudo bash install-master.sh
# =============================================================
set -euo pipefail

MASTER_PUBLIC_IP="103.197.189.7"
# Gunakan private/internal IP jika tersedia untuk flannel,
# fallback ke public IP jika VM tidak punya private network
MASTER_INTERNAL_IP=$(ip route get 1 | awk '{print $7; exit}')

TOKEN_FILE="/tmp/node-token"

echo "================================================"
echo " [MASTER] Install k3s Control Plane"
echo " Public IP   : $MASTER_PUBLIC_IP"
echo " Internal IP : $MASTER_INTERNAL_IP"
echo "================================================"

# ── 1. Update sistem & install dependency ─────────────────────
echo "[1/6] Update sistem..."
apt-get update -qq
apt-get install -y -qq curl wget

# ── 2. Install k3s server ─────────────────────────────────────
echo "[2/6] Installing k3s server..."
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --bind-address="$MASTER_INTERNAL_IP" \
  --advertise-address="$MASTER_PUBLIC_IP" \
  --node-ip="$MASTER_INTERNAL_IP" \
  --node-external-ip="$MASTER_PUBLIC_IP" \
  --node-name="k3s-master" \
  --disable=traefik \
  --disable=servicelb \
  --tls-san="$MASTER_PUBLIC_IP" \
  --tls-san="$MASTER_INTERNAL_IP" \
  --write-kubeconfig-mode=644 \
  --node-taint="node-role.kubernetes.io/master=true:NoSchedule" \
  --node-label="node-role=master"

# ── 3. Tunggu API server siap ─────────────────────────────────
echo "[3/6] Menunggu API server siap..."
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
for i in $(seq 1 24); do
  if kubectl get nodes &>/dev/null; then
    echo "  ✅ API server ready"
    break
  fi
  echo "  ⏳ Attempt $i/24..."
  sleep 5
done

# ── 4. Simpan token ───────────────────────────────────────────
echo "[4/6] Menyimpan node token..."
cat /var/lib/rancher/k3s/server/node-token > "$TOKEN_FILE"
echo ""
echo "  ┌─────────────────────────────────────────────────┐"
echo "  │  NODE TOKEN (copy & simpan untuk worker nodes)  │"
echo "  └─────────────────────────────────────────────────┘"
echo ""
cat "$TOKEN_FILE"
echo ""

# ── 5. Generate kubeconfig untuk akses dari luar ──────────────
echo "[5/6] Generate kubeconfig..."
sed "s/127.0.0.1/$MASTER_PUBLIC_IP/g" /etc/rancher/k3s/k3s.yaml \
  > /root/kubeconfig.yaml
echo ""
echo "  ┌─────────────────────────────────────────────────┐"
echo "  │  KUBECONFIG (copy ke laptop/komputer lokal)     │"
echo "  └─────────────────────────────────────────────────┘"
echo ""
cat /root/kubeconfig.yaml
echo ""

# ── 6. Status akhir ───────────────────────────────────────────
echo "[6/6] Status cluster:"
kubectl get nodes -o wide
echo ""
echo "================================================"
echo " ✅ k3s-master siap!"
echo ""
echo "  Langkah selanjutnya:"
echo "  1. Salin token di atas ke file token di worker"
echo "  2. Buka firewall port 6443 (API server)"
echo "  3. Jalankan install-worker.sh di k3s-app & k3s-gateway"
echo ""
echo "  Firewall yang perlu dibuka di master:"
echo "  - TCP 6443  → API server (dari worker)"
echo "  - UDP 8472  → Flannel VXLAN (dari worker)"
echo "  - TCP 10250 → Kubelet metrics"
echo "================================================"