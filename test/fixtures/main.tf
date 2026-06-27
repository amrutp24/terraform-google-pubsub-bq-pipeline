variable "project" { type = string }
variable "region" { type = string }
variable "topic_name" { type = string }
variable "bq_dataset_id" { type = string }
variable "service_name" { type = string }
variable "image" { type = string }

provider "google" {
  project = var.project
  region  = var.region
}

module "pipeline" {
  source = "../.."

  project       = var.project
  region        = var.region
  topic_name    = var.topic_name
  bq_dataset_id = var.bq_dataset_id
  bq_table_id   = "events"
  image         = var.image
  service_name  = var.service_name

  labels = { purpose = "terratest" }
}

output "cloud_run_url" { value = module.pipeline.cloud_run_url }
output "topic_id" { value = module.pipeline.topic_id }
output "bq_dataset_id" { value = module.pipeline.bq_dataset_id }
output "bq_table_id" { value = module.pipeline.bq_table_id }
