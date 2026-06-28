variable "project" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "topic_name" {
  description = "Name of the Pub/Sub topic"
  type        = string
}

variable "bq_dataset_id" {
  description = "BigQuery dataset ID"
  type        = string
}

variable "bq_table_id" {
  description = "BigQuery table ID"
  type        = string
  default     = "events"
}

variable "bq_dataset_location" {
  description = "BigQuery dataset location"
  type        = string
  default     = "US"
}

variable "image" {
  description = "Docker image URI for the Cloud Run service"
  type        = string
}

variable "service_name" {
  description = "Name of the Cloud Run service"
  type        = string
  default     = "pubsub-to-bq"
}

variable "cloud_run_max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 5
}

variable "cloudrun_sa_account_id" {
  description = "Account ID for the Cloud Run service account (defaults to <service_name>-sa)"
  type        = string
  default     = null
}

variable "pubsub_invoker_sa_account_id" {
  description = "Account ID for the Pub/Sub invoker service account (defaults to <service_name>-invoker)"
  type        = string
  default     = null
}

variable "max_delivery_attempts" {
  description = "Number of delivery attempts before a message is sent to the dead-letter topic"
  type        = number
  default     = 5
}

variable "alert_email" {
  description = "Email address to notify when messages land in the dead-letter topic. Set to null to disable alerting."
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}
