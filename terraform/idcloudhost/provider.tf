terraform {
  required_providers {
    idcloudhost = {
      source  = "bapung/idcloudhost"
      version = "~> 0.2.0"
    }
  }
}

provider "idcloudhost" {
  auth_token = var.auth_token
  region = var.region
}