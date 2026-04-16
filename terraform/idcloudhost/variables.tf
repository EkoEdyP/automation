variable "auth_token" {
  type = string
}

variable "billing_account_id" {
  type = string
}

variable "region" {
  default = "jkt01"
}

variable "password_vm" {
  type = string
  default = "TerraformPassword123!"
}

variable "general_name" {
  type = string
  default = "eep"
}

# variable "vpc_uuid" {
#   type = string
# }

variable "public_key_path" {
  type = string
  default = "~/.ssh/id_ed25519.pub"
}