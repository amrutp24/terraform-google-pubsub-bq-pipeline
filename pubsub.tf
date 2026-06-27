data "google_project" "project" {
  project_id = var.project
}

resource "google_pubsub_topic" "topic" {
  project = var.project
  name    = var.topic_name
  labels  = var.labels

  message_retention_duration = "86600s"
}

resource "google_pubsub_topic" "dead_letter" {
  project = var.project
  name    = "${var.topic_name}-dead-letter"
  labels  = var.labels
}

# Allow Pub/Sub service agent to publish to the dead-letter topic
resource "google_pubsub_topic_iam_member" "dead_letter_publisher" {
  project = var.project
  topic   = google_pubsub_topic.dead_letter.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# Allow Pub/Sub service agent to acknowledge messages from the main subscription
resource "google_pubsub_subscription_iam_member" "dead_letter_subscriber" {
  project      = var.project
  subscription = google_pubsub_subscription.subscription.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
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

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = var.max_delivery_attempts
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  depends_on = [
    google_cloud_run_v2_service.service,
    google_cloud_run_v2_service_iam_member.pubsub_invoker,
    google_pubsub_topic_iam_member.dead_letter_publisher,
  ]
}
