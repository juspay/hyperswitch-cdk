variable "project_id" {
  description = "The GCP project ID where the Helm chart will be deployed."
  type        = string
}

variable "region" {
  description = "The GCP region where the Helm chart will be deployed."
  type        = string
}

variable "stack_name" {
  description = "The name of the stack for tagging and naming resources."
  type        = string
}

variable "gke_cluster_name" {
  description = "The name of the GKE cluster."
  type        = string
}

variable "hyperswitch_namespace" {
  description = "The Kubernetes namespace where the Helm chart will be deployed."
  type        = string
  default     = "hyperswitch"
}

variable "app_cdn_domain_name" {
  description = "The domain name for the application CDN."
  type        = string
}

variable "sdk_cdn_domain_name" {
  description = "The domain name for the SDK CDN."
  type        = string
}

variable "sdk_version" {
  description = "The version of the SDK to be used."
  type        = string
  default = "0.125.0"
}

variable "locker_enabled" {
  description = "Flag to enable or disable the locker service."
  type        = bool
  default = false
}

variable "locker_public_key" {
  description = "The public key for the locker service."
  type        = string
  default = null
}

variable "tenant_private_key" {
  description = "The private key for the tenant in the locker service."
  type        = string
  default = null
}

variable "db_primary_host_endpoint" {
  description = "The host of the external PostgreSQL database."
  type        = string
}

variable "db_reader_host_endpoint" {
  description = "The reader host of the external PostgreSQL database."
  type        = string
}

variable "db_password" {
  description = "The password for the external PostgreSQL database."
  type        = string
}

variable "redis_host_endpoint" {
  description = "The host of the external Redis instance."
  type        = string
}

variable "redis_port" {
  description = "The port for the external Redis instance."
  type        = number
  default     = 6379
}
