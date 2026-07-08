locals {
  compute_instance_filter = var.compute_instance.instance_name_filter != null ? " AND resource.labels.instance_name=~\"${var.compute_instance.instance_name_filter}\"" : ""
  compute_base_filter     = "resource.type=\"gce_instance\"${local.compute_instance_filter}"
  compute_labels          = merge(local.common_labels, { service = "compute-instance" }, var.compute_instance.labels)
}

# ── CPU Utilisation ───────────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "compute_cpu_warning" {
  count        = var.compute_instance.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Compute][WARNING] Instance CPU Utilisation High"
  combiner     = "OR"
  user_labels  = merge(local.compute_labels, local.severity_warning)

  conditions {
    display_name = "Instance CPU utilisation > ${var.compute_instance.cpu_warning_threshold * 100}%"
    condition_threshold {
      filter          = "${local.compute_base_filter} AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.compute_instance.cpu_warning_threshold
      duration        = "${var.compute_instance.duration_warning_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Compute Engine instance CPU has exceeded ${var.compute_instance.cpu_warning_threshold * 100}%. Check for runaway processes or consider resizing the instance. ${var.alert_documentation_prefix}/runbooks/compute-cpu"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "compute_cpu_critical" {
  count        = var.compute_instance.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Compute][CRITICAL] Instance CPU Utilisation Critical"
  combiner     = "OR"
  user_labels  = merge(local.compute_labels, local.severity_critical)

  conditions {
    display_name = "Instance CPU utilisation > ${var.compute_instance.cpu_critical_threshold * 100}%"
    condition_threshold {
      filter          = "${local.compute_base_filter} AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.compute_instance.cpu_critical_threshold
      duration        = "${var.compute_instance.duration_critical_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Compute Engine instance CPU is critically high at ${var.compute_instance.cpu_critical_threshold * 100}%. Instance performance is severely degraded. ${var.alert_documentation_prefix}/runbooks/compute-cpu"
    mime_type = "text/markdown"
  }
}

# ── Memory Utilisation (requires Ops Agent) ───────────────────────────────────

resource "google_monitoring_alert_policy" "compute_memory_warning" {
  count        = var.compute_instance.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Compute][WARNING] Instance Memory Utilisation High"
  combiner     = "OR"
  user_labels  = merge(local.compute_labels, local.severity_warning)

  conditions {
    display_name = "Instance memory utilisation > ${var.compute_instance.memory_warning_threshold * 100}% (requires Ops Agent)"
    condition_threshold {
      filter          = "${local.compute_base_filter} AND metric.type=\"agent.googleapis.com/memory/percent_used\" AND metric.labels.state=\"used\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.compute_instance.memory_warning_threshold * 100
      duration        = "${var.compute_instance.duration_warning_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Compute Engine instance memory utilisation has exceeded ${var.compute_instance.memory_warning_threshold * 100}%. Note: requires Google Cloud Ops Agent to be installed. Check for memory leaks. ${var.alert_documentation_prefix}/runbooks/compute-memory"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "compute_memory_critical" {
  count        = var.compute_instance.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Compute][CRITICAL] Instance Memory Utilisation Critical"
  combiner     = "OR"
  user_labels  = merge(local.compute_labels, local.severity_critical)

  conditions {
    display_name = "Instance memory utilisation > ${var.compute_instance.memory_critical_threshold * 100}% (requires Ops Agent)"
    condition_threshold {
      filter          = "${local.compute_base_filter} AND metric.type=\"agent.googleapis.com/memory/percent_used\" AND metric.labels.state=\"used\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.compute_instance.memory_critical_threshold * 100
      duration        = "${var.compute_instance.duration_critical_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Compute Engine instance memory is critically high at ${var.compute_instance.memory_critical_threshold * 100}%. OOM kills may occur. ${var.alert_documentation_prefix}/runbooks/compute-memory"
    mime_type = "text/markdown"
  }
}

# ── Disk Utilisation (requires Ops Agent) ─────────────────────────────────────

resource "google_monitoring_alert_policy" "compute_disk_warning" {
  count        = var.compute_instance.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Compute][WARNING] Instance Disk Utilisation High"
  combiner     = "OR"
  user_labels  = merge(local.compute_labels, local.severity_warning)

  conditions {
    display_name = "Instance disk utilisation > ${var.compute_instance.disk_warning_threshold * 100}% (requires Ops Agent)"
    condition_threshold {
      filter          = "${local.compute_base_filter} AND metric.type=\"agent.googleapis.com/disk/percent_used\" AND metric.labels.state=\"used\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.compute_instance.disk_warning_threshold * 100
      duration        = "${var.compute_instance.duration_warning_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Compute Engine instance disk is ${var.compute_instance.disk_warning_threshold * 100}% full. Plan for disk expansion or data cleanup. Note: requires Google Cloud Ops Agent. ${var.alert_documentation_prefix}/runbooks/compute-disk"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "compute_disk_critical" {
  count        = var.compute_instance.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Compute][CRITICAL] Instance Disk Near Full"
  combiner     = "OR"
  user_labels  = merge(local.compute_labels, local.severity_critical)

  conditions {
    display_name = "Instance disk utilisation > ${var.compute_instance.disk_critical_threshold * 100}%"
    condition_threshold {
      filter          = "${local.compute_base_filter} AND metric.type=\"agent.googleapis.com/disk/percent_used\" AND metric.labels.state=\"used\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.compute_instance.disk_critical_threshold * 100
      duration        = "${var.compute_instance.duration_critical_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Compute Engine instance disk is ${var.compute_instance.disk_critical_threshold * 100}% full. Disk-full condition will cause application failures. Expand disk immediately. ${var.alert_documentation_prefix}/runbooks/compute-disk"
    mime_type = "text/markdown"
  }
}

# ── Disk I/O Throttling ───────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "compute_disk_throttle_warning" {
  count        = var.compute_instance.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Compute][WARNING] Disk I/O Throttled Operations"
  combiner     = "OR"
  user_labels  = merge(local.compute_labels, local.severity_warning)

  conditions {
    display_name = "Throttled disk ops > ${var.compute_instance.disk_io_warning}/min"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch gce_instance
        | metric 'compute.googleapis.com/instance/disk/throttled_read_ops_count'
        | align rate(1m)
        | group_by [resource.labels.instance_id],
            [read_throttle: sum(val())]
        | join (
            fetch gce_instance
            | metric 'compute.googleapis.com/instance/disk/throttled_write_ops_count'
            | align rate(1m)
            | group_by [resource.labels.instance_id],
                [write_throttle: sum(val())]
          )
        | value read_throttle + write_throttle
        | condition val() > ${var.compute_instance.disk_io_warning}
      EOT
      duration = "${var.compute_instance.duration_warning_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Compute Engine disk I/O is being throttled. This reduces disk throughput and increases latency. Consider upgrading to a higher IOPS disk type. ${var.alert_documentation_prefix}/runbooks/compute-disk-io"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "compute_disk_throttle_critical" {
  count        = var.compute_instance.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Compute][CRITICAL] Disk I/O Throttling Severe"
  combiner     = "OR"
  user_labels  = merge(local.compute_labels, local.severity_critical)

  conditions {
    display_name = "Throttled disk ops > ${var.compute_instance.disk_io_critical}/min"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch gce_instance
        | metric 'compute.googleapis.com/instance/disk/throttled_read_ops_count'
        | align rate(1m)
        | group_by [resource.labels.instance_id],
            [read_throttle: sum(val())]
        | join (
            fetch gce_instance
            | metric 'compute.googleapis.com/instance/disk/throttled_write_ops_count'
            | align rate(1m)
            | group_by [resource.labels.instance_id],
                [write_throttle: sum(val())]
          )
        | value read_throttle + write_throttle
        | condition val() > ${var.compute_instance.disk_io_critical}
      EOT
      duration = "${var.compute_instance.duration_critical_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Compute Engine disk I/O throttling is severe. Storage performance is critically impacted. Upgrade to a higher performance disk type immediately. ${var.alert_documentation_prefix}/runbooks/compute-disk-io"
    mime_type = "text/markdown"
  }
}
