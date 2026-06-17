# All alert policy resources are defined in alerts/*.tf.
# This file manages the Pub/Sub notification channel used by all alert policies.

resource "google_monitoring_notification_channel" "pubsub" {
  count        = var.pubsub_notification_topic != null ? 1 : 0
  project      = var.project_id
  display_name = var.pubsub_notification_channel_display_name
  type         = "pubsub"

  labels = {
    topic = var.pubsub_notification_topic
  }
}
