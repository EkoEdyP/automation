# ========================
# VPC
# ========================
resource "idcloudhost_vpc" "main" {
  name   = "vpc-terraform"
  region = var.region
}

# ========================
# VM APP SERVER (Ubuntu)
# ========================
resource "idcloudhost_vm" "app" {
  name        = "vm-app"
  os_name     = "ubuntu"
  os_version  = "22.04"
  cpu         = 2
  memory      = 2048
  vpc_id      = idcloudhost_vpc.main.id

  billing_account_id = var.billing_account_id
}

# ========================
# VM GATEWAY (Ubuntu)
# ========================
resource "idcloudhost_vm" "gateway" {
  name        = "vm-gateway"
  os_name     = "ubuntu"
  os_version  = "22.04"
  cpu         = 2
  memory      = 2048
  vpc_id      = idcloudhost_vpc.main.id

  billing_account_id = var.billing_account_id
}

# ========================
# FLOATING IP
# ========================
resource "idcloudhost_floating_ip" "app_ip" {
  vm_id = idcloudhost_vm.app.id
}

resource "idcloudhost_floating_ip" "gateway_ip" {
  vm_id = idcloudhost_vm.gateway.id
}

# ========================
# FIREWALL (ALLOW ALL)
# ========================
resource "idcloudhost_firewall" "allow_all" {
  name = "allow-all"

  rule {
    direction = "in"
    protocol  = "all"
    port      = "all"
    source    = "0.0.0.0/0"
  }
}

resource "idcloudhost_firewall_attachment" "app_fw" {
  firewall_id = idcloudhost_firewall.allow_all.id
  vm_id       = idcloudhost_vm.app.id
}

resource "idcloudhost_firewall_attachment" "gateway_fw" {
  firewall_id = idcloudhost_firewall.allow_all.id
  vm_id       = idcloudhost_vm.gateway.id
}

# ========================
# BLOCK STORAGE
# ========================
resource "idcloudhost_volume" "app_volume" {
  name = "volume-app"
  size = 20
}

resource "idcloudhost_volume" "gateway_volume" {
  name = "volume-gateway"
  size = 20
}

# ========================
# ATTACH VOLUME
# ========================
resource "idcloudhost_volume_attachment" "app_attach" {
  vm_id     = idcloudhost_vm.app.id
  volume_id = idcloudhost_volume.app_volume.id
}

resource "idcloudhost_volume_attachment" "gateway_attach" {
  vm_id     = idcloudhost_vm.gateway.id
  volume_id = idcloudhost_volume.gateway_volume.id
}