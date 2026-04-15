output "app_server_ip" {
  value = idcloudhost_floating_ip.app_ip.address
}

output "gateway_server_ip" {
  value = idcloudhost_floating_ip.gateway_ip.address
}