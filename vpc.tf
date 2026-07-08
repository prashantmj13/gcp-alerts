locals {
  vpc_subnet_filter = var.vpc.subnetwork_name != null ? " AND resource.labels.subnetwork_name=\"${var.vpc.subnetwork_name}\"" : ""
  vpc_labels        = merge(local.common_labels, { service = "vpc" }, var.vpc.labels)
}

# ── Subnet IP Utilisation ─────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "vpc_subnet_ip_warning" {
  count        = var.vpc.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[VPC][WARNING] Subnet IP Utilisation High"
  combiner     = "OR"
  user_labels  = merge(local.vpc_labels, local.severity_warning)

  conditions {
    display_name = "Subnet IP utilisation > ${var.vpc.subnet_ip_warning_threshold * 100}%"
    condition_threshold {
      filter          = "resource.type=\"gce_subnetwork\"${local.vpc_subnet_filter} AND metric.type=\"networking.googleapis.com/vpc_flow/subnet_used_address_ratio\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.vpc.subnet_ip_warning_threshold
      duration        = "${var.vpc.duration_warning_secs}s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Subnet IP utilisation has exceeded ${var.vpc.subnet_ip_warning_threshold * 100}%. Plan for subnet expansion before IPs are exhausted. ${var.alert_documentation_prefix}/runbooks/vpc-subnet-ip"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "vpc_subnet_ip_critical" {
  count        = var.vpc.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[VPC][CRITICAL] Subnet IP Exhaustion Imminent"
  combiner     = "OR"
  user_labels  = merge(local.vpc_labels, local.severity_critical)

  conditions {
    display_name = "Subnet IP utilisation > ${var.vpc.subnet_ip_critical_threshold * 100}%"
    condition_threshold {
      filter          = "resource.type=\"gce_subnetwork\"${local.vpc_subnet_filter} AND metric.type=\"networking.googleapis.com/vpc_flow/subnet_used_address_ratio\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.vpc.subnet_ip_critical_threshold
      duration        = "${var.vpc.duration_critical_secs}s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Subnet IP utilisation is critically high at ${var.vpc.subnet_ip_critical_threshold * 100}%. New workloads will fail to start. Expand subnet CIDR immediately. ${var.alert_documentation_prefix}/runbooks/vpc-subnet-ip"
    mime_type = "text/markdown"
  }
}

# ── Secondary Range IP Utilisation ───────────────────────────────────────────
# Monitors alias IP ranges (used by GKE pods and services). Opt-in because not
# all VPCs use secondary ranges. Uses the same metric as the primary range alerts
# but filtered to range_type="SECONDARY".

resource "google_monitoring_alert_policy" "vpc_secondary_ip_warning" {
  count        = var.vpc.enabled && var.vpc.enable_secondary_range_alerts ? 1 : 0
  project      = var.project_id
  display_name = "[VPC][WARNING] Secondary Range IP Utilisation High"
  combiner     = "OR"
  user_labels  = merge(local.vpc_labels, local.severity_warning)

  conditions {
    display_name = "Secondary range IP utilisation > ${var.vpc.secondary_subnet_ip_warning_threshold * 100}%"
    condition_threshold {
      filter          = "resource.type=\"gce_subnetwork\"${local.vpc_subnet_filter} AND metric.type=\"networking.googleapis.com/vpc_flow/subnet_used_address_ratio\" AND metric.labels.range_type=\"SECONDARY\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.vpc.secondary_subnet_ip_warning_threshold
      duration        = "${var.vpc.duration_warning_secs}s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Secondary subnet IP range utilisation has exceeded ${var.vpc.secondary_subnet_ip_warning_threshold * 100}%. GKE pod or service CIDRs may be approaching exhaustion. Plan secondary range expansion. ${var.alert_documentation_prefix}/runbooks/vpc-secondary-ip"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "vpc_secondary_ip_critical" {
  count        = var.vpc.enabled && var.vpc.enable_secondary_range_alerts ? 1 : 0
  project      = var.project_id
  display_name = "[VPC][CRITICAL] Secondary Range IP Exhaustion Imminent"
  combiner     = "OR"
  user_labels  = merge(local.vpc_labels, local.severity_critical)

  conditions {
    display_name = "Secondary range IP utilisation > ${var.vpc.secondary_subnet_ip_critical_threshold * 100}%"
    condition_threshold {
      filter          = "resource.type=\"gce_subnetwork\"${local.vpc_subnet_filter} AND metric.type=\"networking.googleapis.com/vpc_flow/subnet_used_address_ratio\" AND metric.labels.range_type=\"SECONDARY\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.vpc.secondary_subnet_ip_critical_threshold
      duration        = "${var.vpc.duration_critical_secs}s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Secondary subnet IP range utilisation is critically high at ${var.vpc.secondary_subnet_ip_critical_threshold * 100}%. New GKE pods or services may fail to schedule. Expand secondary CIDR ranges immediately. ${var.alert_documentation_prefix}/runbooks/vpc-secondary-ip"
    mime_type = "text/markdown"
  }
}

# ── Firewall Dropped Packets ──────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "vpc_firewall_drops_warning" {
  count        = var.vpc.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[VPC][WARNING] Firewall Dropped Packets High"
  combiner     = "OR"
  user_labels  = merge(local.vpc_labels, local.severity_warning)

  conditions {
    display_name = "Firewall dropped packets > ${var.vpc.firewall_drop_warning}/min"
    condition_threshold {
      filter          = "resource.type=\"gce_subnetwork\"${local.vpc_subnet_filter} AND metric.type=\"networking.googleapis.com/firewall/dropped_packets_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.vpc.firewall_drop_warning
      duration        = "${var.vpc.duration_warning_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.subnetwork_name"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "VPC firewall is dropping more than ${var.vpc.firewall_drop_warning} packets per minute. Review firewall rules and check for misconfigured services. ${var.alert_documentation_prefix}/runbooks/vpc-firewall"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "vpc_firewall_drops_critical" {
  count        = var.vpc.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[VPC][CRITICAL] Firewall Dropped Packets Critical"
  combiner     = "OR"
  user_labels  = merge(local.vpc_labels, local.severity_critical)

  conditions {
    display_name = "Firewall dropped packets > ${var.vpc.firewall_drop_critical}/min"
    condition_threshold {
      filter          = "resource.type=\"gce_subnetwork\"${local.vpc_subnet_filter} AND metric.type=\"networking.googleapis.com/firewall/dropped_packets_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.vpc.firewall_drop_critical
      duration        = "${var.vpc.duration_critical_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.subnetwork_name"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "VPC firewall is dropping more than ${var.vpc.firewall_drop_critical} packets per minute. Potential connectivity outage or security incident. ${var.alert_documentation_prefix}/runbooks/vpc-firewall"
    mime_type = "text/markdown"
  }
}

# ── Cloud NAT Port Allocation Failures ───────────────────────────────────────

resource "google_monitoring_alert_policy" "vpc_nat_alloc_warning" {
  count        = var.vpc.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[VPC][WARNING] NAT Port Allocation Failures"
  combiner     = "OR"
  user_labels  = merge(local.vpc_labels, local.severity_warning)

  conditions {
    display_name = "NAT port allocation failures > ${var.vpc.nat_alloc_fail_warning}"
    condition_threshold {
      filter          = "resource.type=\"nat_gateway\" AND metric.type=\"router.googleapis.com/nat/nat_allocation_failed\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.vpc.nat_alloc_fail_warning
      duration        = "${var.vpc.duration_warning_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.router_id"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud NAT is failing to allocate ports. Outbound connections from VMs without public IPs may be failing. Increase min-ports-per-vm or add more NAT IPs. ${var.alert_documentation_prefix}/runbooks/vpc-nat"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "vpc_nat_alloc_critical" {
  count        = var.vpc.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[VPC][CRITICAL] NAT Port Allocation Critical"
  combiner     = "OR"
  user_labels  = merge(local.vpc_labels, local.severity_critical)

  conditions {
    display_name = "NAT port allocation failures > ${var.vpc.nat_alloc_fail_critical}"
    condition_threshold {
      filter          = "resource.type=\"nat_gateway\" AND metric.type=\"router.googleapis.com/nat/nat_allocation_failed\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.vpc.nat_alloc_fail_critical
      duration        = "${var.vpc.duration_critical_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.router_id"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud NAT port allocation failures are critical. Many outbound connections are failing. Immediately add NAT IP addresses or increase ports-per-vm. ${var.alert_documentation_prefix}/runbooks/vpc-nat"
    mime_type = "text/markdown"
  }
}
