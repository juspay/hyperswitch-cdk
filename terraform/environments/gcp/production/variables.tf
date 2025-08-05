variable "project_id" {
  description = "The ID of the GCP project where resources will be created."
  type        = string
}

variable "region" {
  description = "The GCP region where resources will be created."
  type        = string
  default     = "us-central1"
}
