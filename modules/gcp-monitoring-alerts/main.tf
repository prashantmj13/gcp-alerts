# All alert policy resources are defined in alerts/*.tf.
# This file manages notification channels used by all alert policies.
# Both channels can be active simultaneously — all alerts are sent to every
# configured channel.

resource "google_monitoring_notification_channel" "pubsub" {
  count        = var.pubsub_notification_topic != null ? 1 : 0
  project      = var.project_id
  display_name = var.pubsub_notification_channel_display_name
  type         = "pubsub"

  labels = {
    topic = var.pubsub_notification_topic
  }
}

resource "google_monitoring_notification_channel" "email" {
  for_each     = toset(var.email_notification_addresses)
  project      = var.project_id
  display_name = "GCP Monitoring Alerts - Email (${each.value})"
  type         = "email"

  labels = {
    email_address = each.value
  }
}
