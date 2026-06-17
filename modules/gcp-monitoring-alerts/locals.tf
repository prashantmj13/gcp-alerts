locals {
  common_labels = merge(
    {
      managed_by = "terraform"
      module     = "gcp-monitoring-alerts"
    },
    var.default_labels
  )

  severity_warning  = { severity = "warning" }
  severity_critical = { severity = "critical" }

  # Resolved notification channel list wired to every alert policy.
  # If no Pub/Sub topic is provided, alert policies are created without
  # a channel (alerts remain visible in Cloud Monitoring console).
  notification_channels = var.pubsub_notification_topic != null ? [
    google_monitoring_notification_channel.pubsub[0].name
  ] : []
}
