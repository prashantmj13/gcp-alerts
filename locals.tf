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
  # Combines pre-existing channels, Pub/Sub, and email — all receive every alert.
  # If nothing is configured, policies are created without a channel
  # (alerts remain visible in Cloud Monitoring console only).
  notification_channels = concat(
    var.existing_notification_channel_names,
    var.pubsub_notification_topic != null ? [
      google_monitoring_notification_channel.pubsub[0].name
    ] : [],
    [for ch in google_monitoring_notification_channel.email : ch.name]
  )
}
