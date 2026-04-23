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
TOKEN_FILE="/tmp/node-token"

# Deteksi internal IP dengan fallback yang lebih robust
MASTER_INTERNAL_IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
if [ -z "$MASTER_INTERNAL_IP" ] || [ "$MASTER_INTERNAL_IP" = "$MASTER_PUBLIC_IP" ]; then
  # Fallback: ambil IP dari interface utama
  MASTER_INTERNAL_IP=$(hostname -I | awk '{print $1}')
fi

echo "================================================"
echo " [MASTER] Install k3s Control Plane"
echo " Public IP   : $MASTER_PUBLIC_IP"
echo " Internal IP : $MASTER_INTERNAL_IP"
echo "================================================"

# ── 1. Update sistem & install dependency ─────────────────────
echo "[1/7] Update sistem..."
apt-get update -qq
apt-get install -y -qq curl wget

# ── 2. Install etcd-client ────────────────────────────────────
# Diperlukan untuk: cek etcd member list, hapus ghost member
# saat worker gagal join (duplicate node name error)
echo "[2/7] Install etcd-client..."
apt-get install -y -qq etcd-client
echo "  ✅ etcd-client terinstall: $(etcdctl --version | head -1)"

# Buat wrapper agar etcdctl tidak perlu env panjang
cat > /usr/local/bin/k3s-etcdctl << 'EOF'
#!/usr/bin/env bash
# Wrapper etcdctl untuk k3s — pakai cert k3s otomatis
sudo ETCDCTL_API=3 \
  ETCDCTL_ENDPOINTS=https://127.0.0.1:2379 \
  ETCDCTL_CACERT=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  ETCDCTL_CERT=/var/lib/rancher/k3s/server/tls/etcd/client.crt \
  ETCDCTL_KEY=/var/lib/rancher/k3s/server/tls/etcd/client.key \
  etcdctl "$@"
EOF
chmod +x /usr/local/bin/k3s-etcdctl
echo "  ✅ Wrapper k3s-etcdctl dibuat"
echo "     Contoh: k3s-etcdctl member list"
echo "             k3s-etcdctl member remove <ID>"

# ── 3. Install k3s server ─────────────────────────────────────
echo "[3/7] Installing k3s server..."
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

# ── 4. Tunggu API server siap ─────────────────────────────────
echo "[4/7] Menunggu API server siap..."
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
for i in $(seq 1 24); do
  if kubectl get nodes &>/dev/null; then
    echo "  ✅ API server ready"
    break
  fi
  echo "  ⏳ Attempt $i/24..."
  sleep 5
done

# ── 5. Simpan token ───────────────────────────────────────────
echo "[5/7] Menyimpan node token..."
cat /var/lib/rancher/k3s/server/node-token > "$TOKEN_FILE"
echo ""
echo "  ┌─────────────────────────────────────────────────┐"
echo "  │  NODE TOKEN (copy & simpan untuk worker nodes)  │"
echo "  └─────────────────────────────────────────────────┘"
echo ""
cat "$TOKEN_FILE"
echo ""

# ── 6. Generate kubeconfig ────────────────────────────────────
echo "[6/7] Generate kubeconfig..."
sed "s/127.0.0.1/$MASTER_PUBLIC_IP/g" /etc/rancher/k3s/k3s.yaml \
  > /root/kubeconfig.yaml
echo ""
echo "  ┌─────────────────────────────────────────────────┐"
echo "  │  KUBECONFIG (copy ke laptop/komputer lokal)     │"
echo "  └─────────────────────────────────────────────────┘"
echo ""
cat /root/kubeconfig.yaml
echo ""

# ── 7. Status akhir ───────────────────────────────────────────
echo "[7/7] Status cluster:"
kubectl get nodes -o wide
echo ""
echo "  etcd member list:"
k3s-etcdctl member list
echo ""
echo "================================================"
echo " ✅ k3s-master siap!"
echo ""
echo "  Troubleshooting jika worker gagal join:"
echo "  k3s-etcdctl member list"
echo "  k3s-etcdctl member remove <ID>"
echo ""
echo "  Langkah selanjutnya:"
echo "  1. Salin token di atas ke worker"
echo "  2. Pastikan firewall terbuka:"
echo "     TCP 6443       → API server"
echo "     TCP 2379-2380  → etcd peer"
echo "     UDP 8472       → Flannel VXLAN"
echo "     TCP 10250      → Kubelet"
echo "  3. Jalankan install-worker.sh di k3s-app & k3s-gateway"
echo "================================================"