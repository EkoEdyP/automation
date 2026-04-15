terraform {
  required_providers {
    idcloudhost = {
      source  = "bapung/idcloudhost"
      version = "~> 0.1.0"
    }
  }
}

provider "idcloudhost" {
  api_key = var.api_key
}