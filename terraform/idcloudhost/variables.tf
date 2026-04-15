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