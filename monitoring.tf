resource "google_monitoring_notification_channel" "dead_letter_email" {
  count        = var.alert_email != null ? 1 : 0
  project      = var.project
  display_name = "Dead-letter alert - ${var.topic_name}"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }
}

resource "google_monitoring_alert_policy" "dead_letter" {
  count        = var.alert_email != null ? 1 : 0
  project      = var.project
  display_name = "Dead-letter messages on ${var.topic_name}"
  combiner     = "OR"

  conditions {
    display_name = "Messages published to dead-letter topic"

    condition_threshold {
      filter = join(" AND ", [
        "resource.type = \"pubsub_topic\"",
        "metric.type = \"pubsub.googleapis.com/topic/send_message_operation_count\"",
        "resource.labels.topic_id = \"${var.topic_name}-dead-letter\"",
      ])
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.dead_letter_email[0].name]

  alert_strategy {
    auto_close = "604800s" # auto-close after 7 days if no new data
  }
}
