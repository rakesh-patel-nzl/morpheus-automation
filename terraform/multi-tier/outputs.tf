output "web_ip_addresses" {
  description = "IP address of every web tier VM"
  value       = vsphere_virtual_machine.web[*].default_ip_address
}

output "web_urls" {
  description = "Browse here after running Module 10.8"
  value       = [for ip in vsphere_virtual_machine.web[*].default_ip_address : "http://${ip}"]
}

output "db_ip_address" {
  description = "IP address of the database tier VM"
  value       = vsphere_virtual_machine.db.default_ip_address
}

output "tier_summary" {
  description = "What was built"
  value = {
    application = var.app_name
    web_nodes   = var.web_count
    db_nodes    = 1
    network     = var.network_name
    datastore   = var.datastore
  }
}
