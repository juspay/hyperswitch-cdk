variable "project_id" {
  description = "The ID of the GCP project where resources will be created."
  type        = string
}

variable "region" {
  description = "The GCP region where resources will be created."
  type        = string
  default     = "us-central1"
}

variable "stack_name" {
  description = "The name of the stack for tagging and naming resources."
  type        = string
}

variable "gke_cluster_name" {
  description = "The name of the GKE cluster to connect to."
  type        = string
}
