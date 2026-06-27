output "cloud_run_url" {
  description = "URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.service.uri
}

output "topic_id" {
  description = "Pub/Sub topic ID"
  value       = google_pubsub_topic.topic.id
}

output "subscription_id" {
  description = "Pub/Sub subscription ID"
  value       = google_pubsub_subscription.subscription.id
}

output "bq_dataset_id" {
  description = "BigQuery dataset ID"
  value       = google_bigquery_dataset.dataset.dataset_id
}

output "bq_table_id" {
  description = "BigQuery table ID"
  value       = google_bigquery_table.table.table_id
}

output "dead_letter_topic_id" {
  description = "Dead-letter topic ID — messages that exceed max_delivery_attempts land here"
  value       = google_pubsub_topic.dead_letter.id
}
