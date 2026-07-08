locals {
  gke_cluster_filter   = var.gke.cluster_name != null ? " AND resource.labels.cluster_name=\"${var.gke.cluster_name}\"" : ""
  gke_location_filter  = var.gke.location != null ? " AND resource.labels.location=\"${var.gke.location}\"" : ""
  gke_node_filter      = "resource.type=\"k8s_node\"${local.gke_cluster_filter}${local.gke_location_filter}"
  gke_container_filter = "resource.type=\"k8s_container\"${local.gke_cluster_filter}${local.gke_location_filter}"
  gke_labels           = merge(local.common_labels, { service = "gke" }, var.gke.labels)
}

# ── Node CPU ─────────────────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "gke_node_cpu_warning" {
  count        = var.gke.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[GKE][WARNING] Node CPU Utilisation High"
  combiner     = "OR"
  user_labels  = merge(local.gke_labels, local.severity_warning)

  conditions {
    display_name = "Node CPU allocatable utilisation > ${var.gke.node_cpu_warning_threshold * 100}%"
    condition_threshold {
      filter          = "${local.gke_node_filter} AND metric.type=\"kubernetes.io/node/cpu/allocatable_utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.gke.node_cpu_warning_threshold
      duration        = "${var.gke.duration_warning_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "GKE node CPU utilisation has exceeded the warning threshold of ${var.gke.node_cpu_warning_threshold * 100}%. Review node pool autoscaling configuration. ${var.alert_documentation_prefix}/runbooks/gke-cpu"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "gke_node_cpu_critical" {
  count        = var.gke.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[GKE][CRITICAL] Node CPU Utilisation Critical"
  combiner     = "OR"
  user_labels  = merge(local.gke_labels, local.severity_critical)

  conditions {
    display_name = "Node CPU allocatable utilisation > ${var.gke.node_cpu_critical_threshold * 100}%"
    condition_threshold {
      filter          = "${local.gke_node_filter} AND metric.type=\"kubernetes.io/node/cpu/allocatable_utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.gke.node_cpu_critical_threshold
      duration        = "${var.gke.duration_critical_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "GKE node CPU utilisation has exceeded the critical threshold of ${var.gke.node_cpu_critical_threshold * 100}%. Immediate action required: consider scaling the node pool. ${var.alert_documentation_prefix}/runbooks/gke-cpu"
    mime_type = "text/markdown"
  }
}

# ── Node Memory ───────────────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "gke_node_memory_warning" {
  count        = var.gke.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[GKE][WARNING] Node Memory Utilisation High"
  combiner     = "OR"
  user_labels  = merge(local.gke_labels, local.severity_warning)

  conditions {
    display_name = "Node memory allocatable utilisation > ${var.gke.node_memory_warning_threshold * 100}%"
    condition_threshold {
      filter          = "${local.gke_node_filter} AND metric.type=\"kubernetes.io/node/memory/allocatable_utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.gke.node_memory_warning_threshold
      duration        = "${var.gke.duration_warning_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "GKE node memory utilisation has exceeded the warning threshold of ${var.gke.node_memory_warning_threshold * 100}%. Check for memory-intensive pods and consider node pool scaling. ${var.alert_documentation_prefix}/runbooks/gke-memory"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "gke_node_memory_critical" {
  count        = var.gke.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[GKE][CRITICAL] Node Memory Utilisation Critical"
  combiner     = "OR"
  user_labels  = merge(local.gke_labels, local.severity_critical)

  conditions {
    display_name = "Node memory allocatable utilisation > ${var.gke.node_memory_critical_threshold * 100}%"
    condition_threshold {
      filter          = "${local.gke_node_filter} AND metric.type=\"kubernetes.io/node/memory/allocatable_utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.gke.node_memory_critical_threshold
      duration        = "${var.gke.duration_critical_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "GKE node memory utilisation has exceeded the critical threshold of ${var.gke.node_memory_critical_threshold * 100}%. Risk of OOM kills and pod evictions. ${var.alert_documentation_prefix}/runbooks/gke-memory"
    mime_type = "text/markdown"
  }
}

# ── Container Restarts ────────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "gke_container_restart_warning" {
  count        = var.gke.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[GKE][WARNING] Container Restart Rate High"
  combiner     = "OR"
  user_labels  = merge(local.gke_labels, local.severity_warning)

  conditions {
    display_name = "Container restart count > ${var.gke.container_restart_warning} per 5 minutes"
    condition_threshold {
      filter          = "${local.gke_container_filter} AND metric.type=\"kubernetes.io/container/restart_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.gke.container_restart_warning
      duration        = "${var.gke.duration_warning_secs}s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_DELTA"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "A container has restarted more than ${var.gke.container_restart_warning} times in 5 minutes. Investigate crash logs and resource limits. ${var.alert_documentation_prefix}/runbooks/gke-restarts"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "gke_container_restart_critical" {
  count        = var.gke.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[GKE][CRITICAL] Container Crash Loop Detected"
  combiner     = "OR"
  user_labels  = merge(local.gke_labels, local.severity_critical)

  conditions {
    display_name = "Container restart count > ${var.gke.container_restart_critical} per 5 minutes"
    condition_threshold {
      filter          = "${local.gke_container_filter} AND metric.type=\"kubernetes.io/container/restart_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.gke.container_restart_critical
      duration        = "${var.gke.duration_critical_secs}s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_DELTA"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Container is in CrashLoopBackOff. Restarted more than ${var.gke.container_restart_critical} times in 5 minutes. Check pod logs immediately. ${var.alert_documentation_prefix}/runbooks/gke-restarts"
    mime_type = "text/markdown"
  }
}

# ── Container CPU Limit Utilisation ──────────────────────────────────────────

resource "google_monitoring_alert_policy" "gke_container_cpu_warning" {
  count        = var.gke.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[GKE][WARNING] Container CPU Limit Utilisation High"
  combiner     = "OR"
  user_labels  = merge(local.gke_labels, local.severity_warning)

  conditions {
    display_name = "Container CPU limit utilisation > ${var.gke.container_cpu_warning_threshold * 100}%"
    condition_threshold {
      filter          = "${local.gke_container_filter} AND metric.type=\"kubernetes.io/container/cpu/limit_utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.gke.container_cpu_warning_threshold
      duration        = "${var.gke.duration_warning_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Container CPU is near its configured limit (${var.gke.container_cpu_warning_threshold * 100}%). CPU throttling may be occurring. Consider increasing cpu.limits in the pod spec. ${var.alert_documentation_prefix}/runbooks/gke-cpu-limits"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "gke_container_cpu_critical" {
  count        = var.gke.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[GKE][CRITICAL] Container CPU Limit Saturation"
  combiner     = "OR"
  user_labels  = merge(local.gke_labels, local.severity_critical)

  conditions {
    display_name = "Container CPU limit utilisation > ${var.gke.container_cpu_critical_threshold * 100}%"
    condition_threshold {
      filter          = "${local.gke_container_filter} AND metric.type=\"kubernetes.io/container/cpu/limit_utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.gke.container_cpu_critical_threshold
      duration        = "${var.gke.duration_critical_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Container CPU is at or near its limit (${var.gke.container_cpu_critical_threshold * 100}%). Severe throttling expected. Increase cpu.limits immediately. ${var.alert_documentation_prefix}/runbooks/gke-cpu-limits"
    mime_type = "text/markdown"
  }
}
