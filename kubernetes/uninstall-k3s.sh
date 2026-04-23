#!/usr/bin/env bash
# =============================================================
#  cleanup-k3s.sh
#  Bersihkan instalasi k3s yang gagal/partial secara menyeluruh
#  Jalankan: sudo bash cleanup-k3s.sh
# =============================================================
set -euo pipefail

echo "================================================"
echo " [CLEANUP] Membersihkan instalasi k3s lama"
echo " Host: $(hostname)"
echo " Time: $(date)"
echo "================================================"

# ── 1. Stop & disable service ─────────────────────────────────
echo "[1/8] Stop k3s service..."
systemctl stop k3s        2>/dev/null && echo "  ✅ k3s stopped"       || echo "  ⏭  k3s tidak berjalan"
systemctl stop k3s-agent  2>/dev/null && echo "  ✅ k3s-agent stopped" || echo "  ⏭  k3s-agent tidak berjalan"
systemctl disable k3s       2>/dev/null || true
systemctl disable k3s-agent 2>/dev/null || true

# ── 2. Kill semua proses k3s ──────────────────────────────────
echo "[2/8] Kill proses k3s..."
if [ -f /usr/local/bin/k3s-killall.sh ]; then
  bash /usr/local/bin/k3s-killall.sh 2>/dev/null || true
  echo "  ✅ k3s-killall.sh dijalankan"
fi
for proc in k3s k3s-server k3s-agent containerd; do
  if pgrep -x "$proc" > /dev/null 2>&1; then
    pkill -9 -x "$proc" 2>/dev/null && echo "  ✅ $proc di-kill" || true
  fi
done
sleep 2

# ── 3. Jalankan uninstall script resmi ────────────────────────
echo "[3/8] Jalankan uninstall script resmi..."
if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
  bash /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true
  echo "  ✅ k3s-uninstall.sh dijalankan"
elif [ -f /usr/local/bin/k3s-agent-uninstall.sh ]; then
  bash /usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || true
  echo "  ✅ k3s-agent-uninstall.sh dijalankan"
else
  echo "  ⏭  Tidak ada uninstall script, lanjut manual cleanup..."
fi

# ── 4. Hapus binary & scripts ─────────────────────────────────
echo "[4/8] Hapus binary & scripts..."
for f in \
  /usr/local/bin/k3s \
  /usr/local/bin/kubectl \
  /usr/local/bin/crictl \
  /usr/local/bin/ctr \
  /usr/local/bin/k3s-killall.sh \
  /usr/local/bin/k3s-uninstall.sh \
  /usr/local/bin/k3s-agent-uninstall.sh; do
  rm -f "$f" 2>/dev/null && echo "  🗑  $f" || true
done

# ── 5. Hapus systemd service files ────────────────────────────
echo "[5/8] Hapus systemd service files..."
for f in \
  /etc/systemd/system/k3s.service \
  /etc/systemd/system/k3s-agent.service \
  /etc/systemd/system/k3s.service.env \
  /etc/systemd/system/k3s-agent.service.env \
  /etc/systemd/system/multi-user.target.wants/k3s.service \
  /etc/systemd/system/multi-user.target.wants/k3s-agent.service; do
  rm -f "$f" 2>/dev/null && echo "  🗑  $f" || true
done
systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true

# ── 6. Hapus semua data & config ──────────────────────────────
echo "[6/8] Hapus data & config k3s..."
for d in \
  /var/lib/rancher \
  /etc/rancher \
  /run/k3s \
  /run/flannel \
  /var/log/k3s.log \
  /tmp/k3s-token \
  /tmp/node-token \
  /var/lib/kubelet \
  /etc/kubernetes \
  /var/lib/etcd \
  /etc/cni \
  /opt/cni \
  /var/lib/cni; do
  rm -rf "$d" 2>/dev/null && echo "  🗑  $d" || true
done

# ── 7. Bersihkan network interface sisa ───────────────────────
# ⚠️  TIDAK flush semua iptables — bisa memutus koneksi SSH!
#     Hanya hapus interface flannel/cni dan chain k3s saja.
echo "[7/8] Bersihkan network interface sisa..."
for iface in flannel.1 cni0 vxlan.calico kube-ipvs0 flannel-wg; do
  if ip link show "$iface" &>/dev/null; then
    ip link set "$iface" down 2>/dev/null || true
    ip link delete "$iface" 2>/dev/null && echo "  🗑  interface $iface dihapus" || true
  fi
done

# Hapus hanya chain k3s/flannel — BUKAN flush semua tabel
echo "  Hapus iptables chain k3s/flannel..."
for chain in KUBE-SERVICES KUBE-FORWARD KUBE-NODEPORTS \
             KUBE-PROXY-FIREWALL CNI-FORWARD FLANNEL-FWD \
             KUBE-EXTERNAL-SERVICES KUBE-IPVS-FILTER; do
  iptables -F "$chain" 2>/dev/null || true
  iptables -X "$chain" 2>/dev/null || true
  iptables -t nat -F "$chain" 2>/dev/null || true
  iptables -t nat -X "$chain" 2>/dev/null || true
done
echo "  ✅ iptables chain k3s dibersihkan (koneksi SSH aman)"

# ── 8. Final verifikasi ───────────────────────────────────────
echo ""
echo "[8/8] Verifikasi hasil cleanup..."
echo ""
ISSUES=0

# Cek binary
if command -v k3s &>/dev/null; then
  echo "  ⚠️  k3s binary masih ada: $(which k3s)"
  ISSUES=$((ISSUES + 1))
else
  echo "  ✅ k3s binary    : tidak ada"
fi

# Cek service — fix: cek unit exists, bukan is-active
if systemctl list-unit-files k3s.service 2>/dev/null | grep -q "k3s.service"; then
  echo "  ⚠️  k3s.service masih terdaftar di systemd"
  ISSUES=$((ISSUES + 1))
else
  echo "  ✅ k3s service   : tidak terdaftar"
fi

if systemctl list-unit-files k3s-agent.service 2>/dev/null | grep -q "k3s-agent.service"; then
  echo "  ⚠️  k3s-agent.service masih terdaftar di systemd"
  ISSUES=$((ISSUES + 1))
else
  echo "  ✅ k3s-agent     : tidak terdaftar"
fi

# Cek data directory
if [ -d /var/lib/rancher ] || [ -d /etc/rancher ]; then
  echo "  ⚠️  Direktori rancher masih ada"
  ISSUES=$((ISSUES + 1))
else
  echo "  ✅ Data directory: bersih"
fi

# Cek network interface
if ip link show flannel.1 &>/dev/null || ip link show cni0 &>/dev/null; then
  echo "  ⚠️  Network interface flannel/cni masih ada"
  ISSUES=$((ISSUES + 1))
else
  echo "  ✅ Network iface : bersih"
fi

echo ""
echo "================================================"
if [ "$ISSUES" -eq 0 ]; then
  echo " ✅ Cleanup BERHASIL! Node siap untuk install ulang."
else
  echo " ⚠️  Ada $ISSUES item yang perlu dicek manual."
fi
echo ""
echo " Langkah selanjutnya (install ulang sebagai server):"
echo ""
echo "   # Ambil token dari master:"
echo "   ssh root@103.197.189.7 \\"
echo "     'cat /var/lib/rancher/k3s/server/node-token'"
echo ""
echo "   # Install worker:"
echo "   export K3S_TOKEN=\"<token>\""
echo "   export NODE_ROLE=\"app\"   # atau: gateway"
echo "   sudo -E bash install-worker.sh"
echo "================================================"