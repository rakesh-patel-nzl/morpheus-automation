###############################################################################
# Lab 10 - variables
#
# The three vSphere credential variables default to HPE Morpheus cypher reads.
# Morpheus renders the spec template before Terraform ever sees it, so the
# secret is resolved on the appliance and never stored in Git.
###############################################################################

variable "vsphere_server" {
  description = "vCenter FQDN, for example vcenter.megadata.com"
  type        = string
  default     = "<%=cypher.read('secret/vcenterServer')%>"
}

variable "vsphere_user" {
  description = "vCenter service account"
  type        = string
  default     = "<%=cypher.read('secret/vcenterUser')%>"
}

variable "vsphere_password" {
  description = "vCenter service account password"
  type        = string
  sensitive   = true
  default     = "<%=cypher.read('secret/vcenterPass')%>"
}

# --- Placement -------------------------------------------------------------

variable "datacenter" {
  description = "vCenter datacenter name"
  type        = string
  default     = "MegaData"
}

variable "resource_pool" {
  description = "Resource pool. Use cluster/Resources/pool if the pool is nested in a cluster."
  type        = string
  default     = "MegaData"
}

variable "datastore" {
  description = "Datastore the VMs are created on"
  type        = string
  default     = "BRONZE-Datastore"
}

variable "network_name" {
  description = "Port group the VMs attach to"
  type        = string
  default     = "DEV NET"
}

variable "vm_folder" {
  description = "VM folder path relative to the datacenter"
  type        = string
  default     = "MegaData/Development"
}

variable "vm_template" {
  description = "Existing VM template to clone"
  type        = string
  default     = "template-ubuntu-2404"
}

variable "dns_domain" {
  description = "DNS domain applied by guest customisation"
  type        = string
  default     = "megadata.com"
}

# --- Application sizing ----------------------------------------------------

variable "app_name" {
  description = "Prefix used for every VM this configuration creates"
  type        = string
  default     = "tf-shop"
}

variable "web_count" {
  description = "Number of web tier VMs"
  type        = number
  default     = 1
}

variable "web_cpu" {
  type    = number
  default = 1
}

variable "web_memory" {
  description = "Web tier memory in MB"
  type        = number
  default     = 2048
}

variable "db_cpu" {
  type    = number
  default = 1
}

variable "db_memory" {
  description = "Database tier memory in MB"
  type        = number
  default     = 2048
}

# --- Optional tier configuration (Module 10.8) -----------------------------

variable "configure_tiers" {
  description = "Install PostgreSQL and NGINX and wire the tiers together"
  type        = bool
  default     = false
}

variable "ssh_username" {
  description = "Lab OS account used for remote-exec"
  type        = string
  default     = "morpheusci"
}

variable "ssh_password" {
  description = "Password for ssh_username"
  type        = string
  sensitive   = true
  default     = "<%=cypher.read('secret/labUserPass')%>"
}

variable "app_db_password" {
  description = "Password created for the appuser database account"
  type        = string
  sensitive   = true
  default     = "AppUser123?"
}

variable "app_subnet_cidr" {
  description = "Subnet allowed to reach PostgreSQL"
  type        = string
  default     = "172.30.30.0/24"
}
