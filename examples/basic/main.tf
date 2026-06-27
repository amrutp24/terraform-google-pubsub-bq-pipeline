provider "google" {
  project = var.project
  region  = var.region
}

module "pipeline" {
  source = "../.."

  project    = var.project
  region     = var.region
  topic_name = "my-topic"

  bq_dataset_id = "my_events"
  bq_table_id   = "events"

  image        = "${var.region}-docker.pkg.dev/${var.project}/pubsub-to-bq/app:latest"
  service_name = "pubsub-to-bq"

  labels = {
    environment = "dev"
  }
}

variable "project" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

output "cloud_run_url" {
  value = module.pipeline.cloud_run_url
}
