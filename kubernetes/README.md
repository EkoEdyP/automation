# K3s Cluster – Cloud VM Setup

## Arsitektur

```
         Internet
             │
             ▼
┌────────────────────────────┐
│  k3s-gateway               │  IDCloudHost
│  116.193.191.28            │  Traefik Ingress
│  Port 80 / 443             │
└────────────┬───────────────┘
             │ ClusterIP
             ▼
┌────────────────────────────┐
│  k3s-app                   │  IDCloudHost
│  103.217.144.152           │  Application Workloads
└────────────┬───────────────┘
             │
             ▼
┌────────────────────────────┐
│  k3s-master                │  Biznet Gio
│  103.197.189.7             │  Control Plane
│  Port 6443 (API Server)    │
└────────────────────────────┘
```

## Info VM

| Node        | Provider     | IP Public         | Role          |
|-------------|--------------|-------------------|---------------|
| k3s-master  | Biznet Gio   | 103.197.189.7     | Control Plane |
| k3s-app     | IDCloudHost  | 103.217.144.152   | App Worker    |
| k3s-gateway | IDCloudHost  | 116.193.191.28    | Gateway Worker|

---

## LANGKAH 1 – Buka Firewall / Security Group

Sebelum instalasi, pastikan port berikut sudah dibuka di masing-masing provider.

### Biznet Gio (k3s-master) – Inbound Rules
| Port      | Protokol | Dari               | Keterangan                    |
|-----------|----------|--------------------|-------------------------------|
| 6443      | TCP      | IP VM APP          | API server dari k3s-app       |
| 6443      | TCP      | IP VM GATEWAY      | API server dari k3s-gateway   |
| 8472      | UDP      | IP VM APP          | Flannel VXLAN                 |
| 8472      | UDP      | IP VM GATEWAY      | Flannel VXLAN                 |
| 10250     | TCP      | IP VM APP          | Kubelet                       |
| 10250     | TCP      | IP VM GATEWAY      | Kubelet                       |
| 2379-2380 | TCP      | IP VM APP          | etcd (HA cluster)             |
| 2379-2380 | TCP      | IP VM GATEWAY      | etcd (HA cluster)             |
| 22        | TCP      | Your IP / Anywhere | SSH                           |
| 2380      | TCP      | IP VM GATEWAY      | etcd peer dari k3s-gateway    |
| 2380      | TCP      | IP VM APP          | etcd peer dari k3s-app        |


### IDCloudHost (k3s-app) – Inbound Rules
| Port  | Protokol | Dari               | Keterangan      |
|-------|----------|--------------------|-----------------|
| 8472  | UDP      | IP VM-Master       | Flannel VXLAN   |
| 8472  | UDP      | IP VM GATEWAY      | Flannel VXLAN   |
| 10250 | TCP      | IP VM-Master       | Kubelet         |
| 22    | TCP      | Your IP / Anywhere | SSH             |

### IDCloudHost (k3s-gateway) – Inbound Rules
| Port  | Protokol | Dari               | Keterangan          |
|-------|----------|--------------------|---------------------|
| 80    | TCP      | 0.0.0.0/0          | HTTP ingress        |
| 443   | TCP      | 0.0.0.0/0          | HTTPS ingress       |
| 8080  | TCP      | Your IP / Anywhere | Traefik dashboard   |
| 8472  | UDP      | IP VM-Master       | Flannel VXLAN       |
| 8472  | UDP      | IP VM APP          | Flannel VXLAN       |
| 10250 | TCP      | IP VM-Master       | Kubelet             |
| 22    | TCP      | Your IP / Anywhere | SSH                 |

---

## LANGKAH 2 – Install Master (Biznet Gio)

```bash
# SSH ke master
ssh root@103.197.189.7

# Download & jalankan script
curl -o install-master.sh https://raw.githubusercontent.com/EkoEdyP/automation/main/kubernetes/install-master.sh
# atau scp dari lokal:
# scp scripts/install-master.sh root@103.197.189.7:~

chmod +x install-master.sh
sudo bash install-master.sh
```

Setelah selesai, **catat token** yang muncul di output:
```
K10xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx::server:xxxxxxxxxx
```

---

## LANGKAH 3 – Install Workers (IDCloudHost)

### Install k3s-app (103.217.144.152)
```bash
# SSH ke app worker
ssh root@103.217.144.152

# Download & jalankan script
curl -o install-worker.sh https://raw.githubusercontent.com/EkoEdyP/automation/main/kubernetes/install-worker.sh

curl -o uninstall-k3s.sh https://raw.githubusercontent.com/EkoEdyP/automation/main/kubernetes/uninstall-k3s.sh

# atau scp dari lokal:
# scp scripts/install-master.sh root@103.197.189.7:~

# Set token dari master & role
export K3S_TOKEN="K10xxx...::server:xxx"   # ← paste token dari master
export NODE_ROLE="app"

chmod +x install-worker.sh
chmod +x uninstall-k3s.sh
sudo -E bash install-worker.sh
```

### Install k3s-gateway (116.193.191.28)
```bash
ssh root@116.193.191.28

export K3S_TOKEN="K10xxx...::server:xxx"   # ← token yang sama
export NODE_ROLE="gateway"

chmod +x install-worker.sh
sudo -E bash install-worker.sh
```

---

## LANGKAH 4 – Verifikasi Cluster

```bash
ssh root@103.197.189.7
kubectl get nodes -o wide
```

Output yang diharapkan:
```
NAME          STATUS   ROLES                 IP               EXTERNAL-IP
k3s-master    Ready    control-plane,master  <internal>       103.197.189.7
k3s-app       Ready    <none>               <internal>       103.217.144.152
k3s-gateway   Ready    <none>               <internal>       116.193.191.28
```

Cek label & taint:
```bash
kubectl get nodes --show-labels
kubectl describe node k3s-app     | grep -E "Taint|Label"
kubectl describe node k3s-gateway | grep -E "Taint|Label"
```

---

## LANGKAH 5 – Akses dari Laptop Lokal (Opsional)

```bash
# Salin kubeconfig dari master
scp root@103.197.189.7:/root/kubeconfig.yaml ~/.kube/k3s-cloud.yaml

# Set KUBECONFIG
export KUBECONFIG=~/.kube/k3s-cloud.yaml

# Test
kubectl get nodes
kubectl get pods -A
```

---

## LANGKAH 6 – Deploy Aplikasi

```bash
# Deploy app ke k3s-app
kubectl apply -f manifests/app-deployment.yaml

# Deploy Traefik ke k3s-gateway
kubectl apply -f manifests/gateway-ingress.yaml

# Cek pod berjalan di node yang benar
kubectl get pods -A -o wide
```

Akses lewat gateway:
```
http://116.193.191.28        ← direct IP
http://app.example.com       ← via domain (arahkan DNS ke 116.193.191.28)

Traefik Dashboard:
http://116.193.191.28:8080
```

---

## Troubleshooting

### Node stuck NotReady setelah join
```bash
# Di worker, cek log k3s
journalctl -u k3s -f -n 50

# Cek apakah bisa reach API server
curl -sk https://103.197.189.7:6443/ping
# Jika gagal → cek firewall port 6443 di Biznet Gio
```

### Flannel gagal (pod CIDR tidak terbentuk)
```bash
kubectl get pods -n kube-system | grep flannel
kubectl logs -n kube-system -l app=flannel

# Cek UDP 8472 terbuka antar semua node
```

### Reset node dan join ulang
```bash
# Di worker
sudo k3s-uninstall.sh   # atau k3s-agent-uninstall.sh
# Lalu jalankan install-worker.sh lagi
```

### Lihat semua events
```bash
kubectl get events -A --sort-by=.metadata.creationTimestamp
```