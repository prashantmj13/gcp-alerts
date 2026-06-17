# Full example: all 19 services enabled with custom thresholds.
# Reference configuration for a shared platform / SRE team.
# Alerts flow: Cloud Monitoring → Pub/Sub → Cloud Run function → PagerDuty/Slack/email

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0, < 7.99"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ── Monitoring Module ─────────────────────────────────────────────────────────
# Source from GitHub — pin to a release tag for reproducible builds.
# For Bitbucket: git::https://bitbucket.org/YOUR_ORG/YOUR_REPO.git//modules/gcp-monitoring-alerts?ref=v1.0.0
# For local dev:  ../../modules/gcp-monitoring-alerts

module "monitoring" {
  source = "git::https://github.com/YOUR_ORG/YOUR_REPO.git//modules/gcp-monitoring-alerts?ref=v1.0.0"

  project_id = var.project_id

  pubsub_notification_topic            = "projects/${var.project_id}/topics/${var.alert_topic_name}"
  pubsub_notification_channel_display_name = "SRE Platform Alerts"

  default_labels = {
    team        = "sre"
    env         = "prod"
    cost_center = "platform-001"
  }

  alert_documentation_prefix = "https://runbooks.example.com"

  gke = {
    enabled                         = true
    cluster_name                    = var.gke_cluster_name
    location                        = var.region
    node_cpu_warning_threshold      = 0.70
    node_cpu_critical_threshold     = 0.85
    node_memory_warning_threshold   = 0.75
    node_memory_critical_threshold  = 0.90
    container_restart_warning       = 2
    container_restart_critical      = 8
    container_cpu_warning_threshold = 0.75
  }

  cloud_run = {
    enabled                       = true
    latency_p99_warning_ms        = 1500
    latency_p99_critical_ms       = 4000
    error_rate_warning_threshold  = 0.005
    error_rate_critical_threshold = 0.03
    memory_warning_threshold      = 0.75
  }

  cloud_sql = {
    enabled                        = true
    cpu_warning_threshold          = 0.70
    cpu_critical_threshold         = 0.85
    disk_warning_threshold         = 0.70
    replication_lag_warning_secs   = 20
    replication_lag_critical_secs  = 60
  }

  vpc = {
    enabled                      = true
    subnet_ip_warning_threshold  = 0.65
    subnet_ip_critical_threshold = 0.80
  }

  bigquery = {
    enabled                   = true
    slot_utilization_warning  = 0.75
    slot_utilization_critical = 0.90
    failed_jobs_warning       = 3
    failed_jobs_critical      = 10
  }

  compute_instance = {
    enabled               = true
    cpu_warning_threshold = 0.70
  }

  load_balancer = {
    enabled                 = true
    latency_p95_warning_ms  = 800
    latency_p95_critical_ms = 2000
    ssl_expiry_warning_days = 45
  }

  pubsub = {
    enabled                      = true
    oldest_message_warning_secs  = 30
    oldest_message_critical_secs = 120
    undelivered_warning          = 500
  }

  cloud_armor = {
    enabled                  = true
    denied_requests_warning  = 50
    denied_requests_critical = 500
  }

  vertex_ai = {
    enabled                = true
    latency_p99_warning_ms = 1500
    cpu_warning_threshold  = 0.70
    pipeline_fail_warning  = 1
  }

  apigee = {
    enabled                      = true
    latency_p99_warning_ms       = 1500
    error_rate_warning_threshold = 0.005
  }

  mig = {
    enabled                        = true
    autoscaler_utilization_warning = 0.75
  }

  cloud_storage = {
    enabled              = true
    error_count_warning  = 30
    error_count_critical = 100
    # Uncomment to enable cost-control alerts (value in bytes):
    # total_bytes_warning  = 1073741824000  # 1 TB
    # total_bytes_critical = 5368709120000  # 5 TB
  }

  gemini = {
    enabled                      = true
    error_rate_warning_threshold = 0.03
    quota_warning_threshold      = 0.70
  }

  ncc = {
    enabled = true
  }

  secret_manager = {
    enabled                = true
    access_denied_warning  = 2
    access_denied_critical = 5
  }

  certificate_manager = {
    enabled              = true
    expiry_warning_days  = 45
    expiry_critical_days = 14
  }

  project_quotas = {
    enabled                       = true
    allocation_warning_threshold  = 0.70
    allocation_critical_threshold = 0.85
  }
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "notification_channel" {
  description = "Pub/Sub notification channel resource name."
  value       = module.monitoring.pubsub_notification_channel_name
}

output "enabled_services" {
  description = "All services for which alert policies are active."
  value       = module.monitoring.enabled_services
}

output "alert_policy_ids" {
  description = "All created alert policy resource names."
  value       = module.monitoring.alert_policy_ids
}

# ── Variables ─────────────────────────────────────────────────────────────────

variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "asia-southeast1"
}

variable "gke_cluster_name" {
  type    = string
  default = null
}

variable "alert_topic_name" {
  description = "Name of the existing Pub/Sub topic that receives alert notifications"
  type        = string
}
