resource "google_bigquery_dataset" "dataset" {
  project    = var.project
  dataset_id = var.bq_dataset_id
  location   = var.bq_dataset_location
  labels     = var.labels
}

resource "google_bigquery_table" "table" {
  project             = var.project
  dataset_id          = google_bigquery_dataset.dataset.dataset_id
  table_id            = var.bq_table_id
  deletion_protection = false

  schema = jsonencode([
    {
      name        = "message_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Pub/Sub message ID"
    },
    {
      name        = "publish_time"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "Pub/Sub publish timestamp"
    },
    {
      name        = "data"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Raw decoded message data"
    },
    {
      name        = "attributes"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Pub/Sub message attributes as JSON string"
    }
  ])
}
