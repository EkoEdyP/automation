# Terraform IDCloudHost

## 📌 Fitur

* 2 Virtual Machine (Ubuntu 22.04 LTS)

  * **VM 1 (App Server)**

    * 2 CPU
    * 2 GB RAM
    * Menjalankan Frontend & Backend

  * **VM 2 (Gateway Server)**

    * 2 CPU
    * 2 GB RAM
    * Menjalankan Nginx & Database

* Storage: 20 GB (masing-masing VM)

* Location: Indonesia (South Jakarta / jkt01)

* Server Class: Basic Standard

* VPC Network

* Static Public IP

* Firewall (Allow All: 0.0.0.0/0)

* Block Storage (2 volume, masing-masing VM 1)

---

## 📁 Struktur Folder

```
idcloudhost/
├── provider.tf
├── variables.tf
├── main.tf
├── outputs.tf
├── terraform.tfvars
└── README.md
```

---

## 📄 Penjelasan File

### 1. `provider.tf`

Berisi konfigurasi provider Terraform untuk IDCloudHost.

* Mendefinisikan provider yang digunakan
* Menghubungkan Terraform dengan API IDCloudHost menggunakan API Key

---

### 2. `variables.tf`

Berisi deklarasi variabel yang digunakan dalam project.

* `api_key` → API Key dari IDCloudHost
* `billing_account_id` → ID billing akun
* `region` → lokasi server (default: jkt01)

---

### 3. `main.tf`

File utama yang berisi semua resource yang akan dibuat:

* VPC Network
* 2 Virtual Machine (App & Gateway)
* Floating IP (Static IP)
* Firewall (Allow All)
* Block Storage (2 volume)
* Attachment storage ke masing-masing VM

---

### 4. `outputs.tf`

Digunakan untuk menampilkan hasil setelah Terraform dijalankan.

* IP Address App Server
* IP Address Gateway Server

---

### 5. `terraform.tfvars`

Berisi nilai dari variabel yang digunakan.

⚠️ **Penting:**

* Menyimpan API Key dan Billing ID
* Jangan di-commit ke GitHub (tambahkan ke `.gitignore`)

Contoh:

```
api_key            = "YOUR_API_KEY"
billing_account_id = "YOUR_BILLING_ID"
```

---

### 6. `README.md`

Dokumentasi project.

* Menjelaskan fitur
* Cara penggunaan
* Struktur project

---

## 🚀 Cara Pakai

### 1. Inisialisasi Terraform

```
terraform init
```

### 2. Cek Plan

```
terraform plan
```

### 3. Deploy Resource

```
terraform apply
```

---

## 🔐 Akses Server

Gunakan SSH:

```
ssh root@IP_APP_SERVER
ssh root@IP_GATEWAY
```

---

## ⚠️ Catatan

* Gunakan API Key dengan **Full Access & Global Scope**
* Pastikan billing aktif
* Firewall `0.0.0.0/0` hanya untuk kebutuhan lab (tidak aman untuk production)
* Jangan commit file `terraform.tfvars`

---

## 📌 Author

[EkoEdyP](https://github.com/EkoEdyP)

Project ini dibuat untuk kebutuhan provisioning infrastructure menggunakan Terraform di IDCloudHost.
