variable "yc_token" {
  description = "Yandex Cloud OAuth token"
  type        = string
  sensitive   = true
}

variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "folder_id" {
  description = "Folder ID"
  type        = string
}

variable "zone" {
  description = "Availability zone"
  type        = string
  default     = "ru-central1-a"
}

variable "subnet_cidr" {
  description = "CIDR for subnet"
  type        = string
  default     = "10.10.0.0/24"
}

variable "ssh_public_key" {
  description = "SSH public key for VMs"
  type        = string
}

variable "med_db_password" {
  description = "Password for medical DB user"
  type        = string
  sensitive   = true
}

variable "fin_db_password" {
  description = "Password for fintech DB user"
  type        = string
  sensitive   = true
}

variable "mdm_db_password" {
  description = "Password for MDM DB user"
  type        = string
  sensitive   = true
}