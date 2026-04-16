# ========================
# VPC (VIRTUAL PRIVATE CLOUD)
# ========================
resource "idcloudhost_network" "main" {
  name   = "${var.general_name}-vpc"
  # uuid   = var.vpc_uuid
}

# ========================
# VM APP SERVER (Ubuntu)
# ========================
resource "idcloudhost_vm" "app" {
  billing_account_id = var.billing_account_id
  disks       = 20
  initial_password = var.password_vm
  memory      = 2048
  name        = "${var.general_name}-vm-app"
  os_name     = "ubuntu"
  os_version  = "22.04"
  username    = "${var.general_name}-ubuntu-app"
  vcpu        = 2
  public_key = file(var.public_key_path)

  # source_uuid = idcloudhost_network.main.uuid
}

# ========================
# VM GATEWAY (Ubuntu)
# ========================
resource "idcloudhost_vm" "gateway" {
  billing_account_id = var.billing_account_id
  disks       = 20
  initial_password = var.password_vm
  memory      = 2048
  name        = "${var.general_name}-vm-gateway"
  os_name     = "ubuntu"
  os_version  = "22.04"
  username    = "${var.general_name}-ubuntu-gateway"
  vcpu        = 2
  public_key = file(var.public_key_path)

  # source_uuid = idcloudhost_network.main.uuid
}

# ========================
# FLOATING IP
# ========================
resource "idcloudhost_floating_ip" "app_ip" {
  name               = "${var.general_name}-floating-ip-app"
  billing_account_id = var.billing_account_id
  assigned_to = idcloudhost_vm.app.id
}

resource "idcloudhost_floating_ip" "gateway_ip" {
  name               = "${var.general_name}-floating-ip-gateway"
  billing_account_id = var.billing_account_id
  assigned_to = idcloudhost_vm.gateway.id
}

# ========================
# FIREWALL (ALLOW ALL)
# ========================
resource "idcloudhost_firewall" "allow_all" {
  billing_account_id = var.billing_account_id
  display_name = "${var.general_name}-firewall"

  # Rule: Allow all inbound TCP dari semua IP
  rules {
    direction  = "inbound"
    endpoint_spec_type = "any"
    protocol   = "tcp"
    endpoint_spec = ["0.0.0.0/0"]
    port_start = 1
    port_end   = 65535
  }

  # Rule: Allow all inbound UDP dari semua IP
  rules {
    direction  = "inbound"
    endpoint_spec_type = "any"
    protocol   = "udp"
    endpoint_spec = ["0.0.0.0/0"]
    port_start = 1
    port_end   = 65535
  }

  # Rule: Allow ICMP (ping) dari semua IP
  rules {
    direction = "inbound"
    endpoint_spec_type = "any"
    protocol  = "icmp"
    endpoint_spec = ["0.0.0.0/0"]
  }
}


# ========================
# OBJECT STORAGE
# ========================
resource "idcloudhost_objectstorage" "app_bucket" {
  billing_account_id = var.billing_account_id
  name = "${var.general_name}-bucket-app"
}

resource "idcloudhost_objectstorage" "gateway_bucket" {
  billing_account_id = var.billing_account_id
  name = "${var.general_name}-bucket-gateway"
}