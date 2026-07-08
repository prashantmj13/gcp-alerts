locals {
  pubsub_sub_filter  = var.pubsub.subscription_filter != null ? " AND resource.labels.subscription_id=~\"${var.pubsub.subscription_filter}\"" : ""
  pubsub_sub_base    = "resource.type=\"pubsub_subscription\"${local.pubsub_sub_filter}"
  pubsub_topic_base  = "resource.type=\"pubsub_topic\""
  pubsub_labels      = merge(local.common_labels, { service = "pubsub" }, var.pubsub.labels)
}

# ── Oldest Unacked Message Age ────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "pubsub_oldest_message_warning" {
  count        = var.pubsub.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[PubSub][WARNING] Subscription Message Backlog Growing"
  combiner     = "OR"
  user_labels  = merge(local.pubsub_labels, local.severity_warning)

  conditions {
    display_name = "Oldest unacked message age > ${var.pubsub.oldest_message_warning_secs}s"
    condition_threshold {
      filter          = "${local.pubsub_sub_base} AND metric.type=\"pubsub.googleapis.com/subscription/oldest_unacked_message_age\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.pubsub.oldest_message_warning_secs
      duration        = "${var.pubsub.duration_warning_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MAX"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Pub/Sub subscription has messages older than ${var.pubsub.oldest_message_warning_secs}s. Consumers may be struggling to keep up with the message rate. Check consumer health and throughput. ${var.alert_documentation_prefix}/runbooks/pubsub-backlog"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "pubsub_oldest_message_critical" {
  count        = var.pubsub.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[PubSub][CRITICAL] Subscription Message Backlog Critical"
  combiner     = "OR"
  user_labels  = merge(local.pubsub_labels, local.severity_critical)

  conditions {
    display_name = "Oldest unacked message age > ${var.pubsub.oldest_message_critical_secs}s"
    condition_threshold {
      filter          = "${local.pubsub_sub_base} AND metric.type=\"pubsub.googleapis.com/subscription/oldest_unacked_message_age\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.pubsub.oldest_message_critical_secs
      duration        = "${var.pubsub.duration_critical_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MAX"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Pub/Sub subscription has messages older than ${var.pubsub.oldest_message_critical_secs}s. Consumers are significantly behind. Scale up consumers immediately. ${var.alert_documentation_prefix}/runbooks/pubsub-backlog"
    mime_type = "text/markdown"
  }
}

# ── Undelivered Message Count ─────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "pubsub_undelivered_warning" {
  count        = var.pubsub.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[PubSub][WARNING] Undelivered Messages High"
  combiner     = "OR"
  user_labels  = merge(local.pubsub_labels, local.severity_warning)

  conditions {
    display_name = "Undelivered message count > ${var.pubsub.undelivered_warning}"
    condition_threshold {
      filter          = "${local.pubsub_sub_base} AND metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.pubsub.undelivered_warning
      duration        = "${var.pubsub.duration_warning_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Pub/Sub subscription has more than ${var.pubsub.undelivered_warning} undelivered messages. Consumer throughput is insufficient. ${var.alert_documentation_prefix}/runbooks/pubsub-backlog"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "pubsub_undelivered_critical" {
  count        = var.pubsub.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[PubSub][CRITICAL] Undelivered Messages Critical"
  combiner     = "OR"
  user_labels  = merge(local.pubsub_labels, local.severity_critical)

  conditions {
    display_name = "Undelivered message count > ${var.pubsub.undelivered_critical}"
    condition_threshold {
      filter          = "${local.pubsub_sub_base} AND metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.pubsub.undelivered_critical
      duration        = "${var.pubsub.duration_critical_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Pub/Sub subscription has more than ${var.pubsub.undelivered_critical} undelivered messages. Messages may start expiring. Scale consumers immediately or check for consumer failures. ${var.alert_documentation_prefix}/runbooks/pubsub-backlog"
    mime_type = "text/markdown"
  }
}

# ── Dead Letter Queue ─────────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "pubsub_dead_letter_warning" {
  count        = var.pubsub.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[PubSub][WARNING] Dead Letter Messages Accumulating"
  combiner     = "OR"
  user_labels  = merge(local.pubsub_labels, local.severity_warning)

  conditions {
    display_name = "Dead letter message count > ${var.pubsub.dead_letter_warning}"
    condition_threshold {
      filter          = "${local.pubsub_sub_base} AND metric.type=\"pubsub.googleapis.com/subscription/dead_letter_message_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.pubsub.dead_letter_warning
      duration        = "${var.pubsub.duration_warning_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Pub/Sub dead letter queue has accumulated ${var.pubsub.dead_letter_warning}+ messages. Messages are failing to process successfully. Investigate processing errors. ${var.alert_documentation_prefix}/runbooks/pubsub-dlq"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "pubsub_dead_letter_critical" {
  count        = var.pubsub.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[PubSub][CRITICAL] Dead Letter Queue Critical"
  combiner     = "OR"
  user_labels  = merge(local.pubsub_labels, local.severity_critical)

  conditions {
    display_name = "Dead letter message count > ${var.pubsub.dead_letter_critical}"
    condition_threshold {
      filter          = "${local.pubsub_sub_base} AND metric.type=\"pubsub.googleapis.com/subscription/dead_letter_message_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.pubsub.dead_letter_critical
      duration        = "${var.pubsub.duration_critical_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Pub/Sub dead letter queue has accumulated ${var.pubsub.dead_letter_critical}+ messages. Systematic processing failures detected. Investigate and fix consumer errors. ${var.alert_documentation_prefix}/runbooks/pubsub-dlq"
    mime_type = "text/markdown"
  }
}

# ── Topic Publish Errors ──────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "pubsub_publish_errors_warning" {
  count        = var.pubsub.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[PubSub][WARNING] Topic Publish Errors High"
  combiner     = "OR"
  user_labels  = merge(local.pubsub_labels, local.severity_warning)

  conditions {
    display_name = "Topic publish errors > ${var.pubsub.publish_error_warning}/min"
    condition_threshold {
      filter          = "${local.pubsub_topic_base} AND metric.type=\"pubsub.googleapis.com/topic/send_request_count\" AND metric.labels.response_class!=\"success\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.pubsub.publish_error_warning
      duration        = "${var.pubsub.duration_warning_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.topic_id"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Pub/Sub topic is receiving publish errors at a rate > ${var.pubsub.publish_error_warning}/min. Publishers may be experiencing failures. Check IAM permissions and quota. ${var.alert_documentation_prefix}/runbooks/pubsub-publish"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "pubsub_publish_errors_critical" {
  count        = var.pubsub.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[PubSub][CRITICAL] Topic Publish Errors Critical"
  combiner     = "OR"
  user_labels  = merge(local.pubsub_labels, local.severity_critical)

  conditions {
    display_name = "Topic publish errors > ${var.pubsub.publish_error_critical}/min"
    condition_threshold {
      filter          = "${local.pubsub_topic_base} AND metric.type=\"pubsub.googleapis.com/topic/send_request_count\" AND metric.labels.response_class!=\"success\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.pubsub.publish_error_critical
      duration        = "${var.pubsub.duration_critical_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.topic_id"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Pub/Sub topic publish errors are critical at > ${var.pubsub.publish_error_critical}/min. Data pipeline may be losing messages. ${var.alert_documentation_prefix}/runbooks/pubsub-publish"
    mime_type = "text/markdown"
  }
}
