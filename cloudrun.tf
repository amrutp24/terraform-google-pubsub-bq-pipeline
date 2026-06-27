locals {
  cloudrun_sa_account_id       = coalesce(var.cloudrun_sa_account_id, "${var.service_name}-sa")
  pubsub_invoker_sa_account_id = coalesce(var.pubsub_invoker_sa_account_id, "${var.service_name}-invoker")
}

resource "google_artifact_registry_repository" "repo" {
  project       = var.project
  location      = var.region
  repository_id = var.service_name
  description   = "Docker images for ${var.service_name}"
  format        = "DOCKER"
}

resource "google_service_account" "cloudrun_sa" {
  project      = var.project
  account_id   = local.cloudrun_sa_account_id
  display_name = "Cloud Run - ${var.service_name}"
}

resource "google_project_iam_member" "cloudrun_bq_data_editor" {
  project = var.project
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

resource "google_project_iam_member" "cloudrun_bq_job_user" {
  project = var.project
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

resource "google_cloud_run_v2_service" "service" {
  project  = var.project
  name     = var.service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = google_service_account.cloudrun_sa.email

    scaling {
      min_instance_count = 0
      max_instance_count = var.cloud_run_max_instances
    }

    containers {
      image = var.image

      env {
        name  = "BQ_PROJECT"
        value = var.project
      }
      env {
        name  = "BQ_DATASET"
        value = google_bigquery_dataset.dataset.dataset_id
      }
      env {
        name  = "BQ_TABLE"
        value = google_bigquery_table.table.table_id
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
  }

  depends_on = [google_artifact_registry_repository.repo]
}

resource "google_service_account" "pubsub_invoker_sa" {
  project      = var.project
  account_id   = local.pubsub_invoker_sa_account_id
  display_name = "Pub/Sub invoker for ${var.service_name}"
}

resource "google_cloud_run_v2_service_iam_member" "pubsub_invoker" {
  project  = var.project
  location = var.region
  name     = google_cloud_run_v2_service.service.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.pubsub_invoker_sa.email}"
}
