resource "google_pubsub_topic" "topic" {
  project = var.project
  name    = var.topic_name
  labels  = var.labels

  message_retention_duration = "86600s"
}

resource "google_pubsub_subscription" "subscription" {
  project = var.project
  name    = "${var.topic_name}-to-cloudrun"
  topic   = google_pubsub_topic.topic.name

  ack_deadline_seconds = 60

  push_config {
    push_endpoint = google_cloud_run_v2_service.service.uri

    oidc_token {
      service_account_email = google_service_account.pubsub_invoker_sa.email
    }
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  depends_on = [
    google_cloud_run_v2_service.service,
    google_cloud_run_v2_service_iam_member.pubsub_invoker,
  ]
}
