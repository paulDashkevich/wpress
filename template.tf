resource "local_file" "AnsibleInventory" {
  content = templatefile("ansible/inventory.tpl",
    {
      ip               = ah_cloud_server.pcm.*.ips.0.ip_address,
      int_ip           = ah_private_network_connection.lan1.*.ip_address
      int_ip2          = ah_private_network_connection.lan2.*.ip_address
      proxy_reverse_ip = ah_cloud_server.pcm[4].*.ips.0.reverse_dns
    }
  )
  filename = "hosts"
}
