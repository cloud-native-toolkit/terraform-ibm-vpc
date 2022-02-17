# Resource Group Variables
variable "resource_group_name" {
  type        = string
  description = "The name of the IBM Cloud resource group where the VPC instance will be created."
}

variable "region" {
  type        = string
  description = "The IBM Cloud region where the cluster will be/has been installed."
}

variable "name" {
  type        = string
  description = "The name of the vpc instance"
  default     = ""
}

variable "name_prefix" {
  type        = string
  description = "The name of the vpc resource"
  default     = ""
}

variable "provision" {
  type        = bool
  description = "Flag indicating that the instance should be provisioned. If false then an existing instance will be looked up"
  default     = true
}

variable "address_prefix_count" {
  type        = number
  description = "The number of ipv4_cidr_blocks"
  default     = 0
}

variable "address_prefixes" {
  type        = list(string)
  description = "List of ipv4 cidr blocks for the address prefixes (e.g. ['10.10.10.0/24']). If you are providing cidr blocks then a value must be provided for each of the subnets. If you don't provide cidr blocks for each of the subnets then values will be generated using the {ipv4_address_count} value."
  default     = []
}

variable "base_security_group_name" {
  type        = string
  description = "The name of the base security group. If not provided the name will be based on the vpc name"
  default     = ""
}

variable "internal_cidr" {
  type        = string
  description = "The cidr range of the internal network"
  default     = "10.0.0.0/8"
}

variable "enabled" {
  type        = bool
  description = "Flag to indicate that IBM VPC module should be enabled"
  default     = true
}
