###############################################################################
# Lab 10 - HPE Morpheus Enterprise: multi-tier application with Terraform
#
# Builds a two-tier application in the class vCenter by cloning the existing
# Ubuntu template:  N x web tier VM  +  1 x database tier VM.
#
# Secrets are read from HPE Morpheus cyphers when the spec template is
# rendered, so no credential is ever committed to Git.
###############################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.6"
    }
  }
}

provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
}

###############################################################################
# Look up the existing objects in vCenter
###############################################################################

data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

data "vsphere_datastore" "datastore" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = var.resource_pool
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.network_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.vm_template
  datacenter_id = data.vsphere_datacenter.dc.id
}

###############################################################################
# Database tier - one VM
###############################################################################

resource "vsphere_virtual_machine" "db" {
  name             = "${var.app_name}-db"
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = var.vm_folder

  num_cpus = var.db_cpu
  memory   = var.db_memory
  guest_id = data.vsphere_virtual_machine.template.guest_id

  # Inherit firmware and controller type from the template. Without the
  # firmware line the provider defaults to BIOS, and an EFI template then
  # fails to power on with "ACPI motherboard layout requires EFI".
  firmware  = data.vsphere_virtual_machine.template.firmware
  scsi_type = data.vsphere_virtual_machine.template.scsi_type

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = data.vsphere_virtual_machine.template.disks.0.size
    thin_provisioned = data.vsphere_virtual_machine.template.disks.0.thin_provisioned
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = "${var.app_name}-db"
        domain    = var.dns_domain
      }

      network_interface {}
    }
  }

  wait_for_guest_net_timeout = 10
}

###############################################################################
# Web tier - var.web_count VMs
###############################################################################

resource "vsphere_virtual_machine" "web" {
  count = var.web_count

  name             = format("%s-web-%02d", var.app_name, count.index + 1)
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = var.vm_folder

  num_cpus = var.web_cpu
  memory   = var.web_memory
  guest_id = data.vsphere_virtual_machine.template.guest_id

  # Inherit firmware and controller type from the template. Without the
  # firmware line the provider defaults to BIOS, and an EFI template then
  # fails to power on with "ACPI motherboard layout requires EFI".
  firmware  = data.vsphere_virtual_machine.template.firmware
  scsi_type = data.vsphere_virtual_machine.template.scsi_type

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = data.vsphere_virtual_machine.template.disks.0.size
    thin_provisioned = data.vsphere_virtual_machine.template.disks.0.thin_provisioned
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = format("%s-web-%02d", var.app_name, count.index + 1)
        domain    = var.dns_domain
      }

      network_interface {}
    }
  }

  wait_for_guest_net_timeout = 10
}

###############################################################################
# OPTIONAL tier configuration (Module 10.8)
# Set configure_tiers = true to install PostgreSQL on the database tier and
# NGINX on the web tier, and to point the web tier at the database.
###############################################################################

resource "null_resource" "configure_db" {
  count = var.configure_tiers ? 1 : 0

  connection {
    type     = "ssh"
    host     = vsphere_virtual_machine.db.default_ip_address
    user     = var.ssh_username
    password = var.ssh_password
    timeout  = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -qq",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql",
      "sudo -u postgres psql -c \"CREATE DATABASE appdb;\"",
      "sudo -u postgres psql -c \"CREATE USER appuser WITH PASSWORD '${var.app_db_password}';\"",
      "sudo -u postgres psql -c \"GRANT ALL PRIVILEGES ON DATABASE appdb TO appuser;\"",
      "sudo sed -i \"s/^#*listen_addresses.*/listen_addresses = '*'/\" /etc/postgresql/*/main/postgresql.conf",
      "echo 'host all all ${var.app_subnet_cidr} md5' | sudo tee -a /etc/postgresql/*/main/pg_hba.conf",
      "sudo systemctl restart postgresql"
    ]
  }
}

resource "null_resource" "configure_web" {
  count = var.configure_tiers ? var.web_count : 0

  depends_on = [null_resource.configure_db]

  connection {
    type     = "ssh"
    host     = vsphere_virtual_machine.web[count.index].default_ip_address
    user     = var.ssh_username
    password = var.ssh_password
    timeout  = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -qq",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx postgresql-client",
      "echo '<h1>${var.app_name} web tier</h1>' | sudo tee /var/www/html/index.html",
      "echo '<p>Web node: '$(hostname)' at '$(hostname -I)'</p>' | sudo tee -a /var/www/html/index.html",
      "echo '<p>Database tier: ${vsphere_virtual_machine.db.default_ip_address}</p>' | sudo tee -a /var/www/html/index.html",
      "pg_isready -h ${vsphere_virtual_machine.db.default_ip_address} -p 5432 | sudo tee -a /var/www/html/index.html",
      "sudo systemctl enable --now nginx"
    ]
  }
}
