# GKE team example: platform team running GKE workloads with compute, MIG,
# load balancer, and Pub/Sub. Demonstrates per-service threshold customisation.
# Alerts flow: Cloud Monitoring → Pub/Sub → Cloud Run function → Moogsoft

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
# For Bitbucket: git::https://bitbucket.org/YOUR_ORG/YOUR_REPO.git?ref=v1.0.0
# For local dev:  ../../

module "monitoring" {
  source = "git::https://github.com/YOUR_ORG/YOUR_REPO.git?ref=v1.0.0"

  project_id = var.project_id

  pubsub_notification_topic            = "projects/${var.project_id}/topics/${var.alert_topic_name}"
  pubsub_notification_channel_display_name = "GKE Team Alerts - ${var.environment}"

  default_labels = {
    team        = "platform"
    env         = var.environment
    cost_center = "infra-001"
  }

  alert_documentation_prefix = "https://wiki.example.com"

  # ── GKE: tighter thresholds for production cluster ──────────────────────────
  gke = {
    enabled      = true
    cluster_name = var.gke_cluster_name
    location     = var.region

    node_cpu_warning_threshold      = 0.70
    node_cpu_critical_threshold     = 0.85
    node_memory_warning_threshold   = 0.80
    node_memory_critical_threshold  = 0.88
    container_restart_warning       = 2
    container_restart_critical      = 8
    duration_critical_secs          = 60
  }

  vpc = {
    enabled                      = true
    subnet_ip_warning_threshold  = 0.65
    subnet_ip_critical_threshold = 0.80
    firewall_drop_warning        = 50
    firewall_drop_critical       = 300
  }

  compute_instance = {
    enabled               = true
    cpu_warning_threshold = 0.70
  }

  mig = {
    enabled                        = true
    autoscaler_utilization_warning = 0.80
  }

  load_balancer = {
    enabled                      = true
    latency_p95_warning_ms       = 800
    latency_p95_critical_ms      = 2000
    error_rate_warning_threshold = 0.005
    ssl_expiry_warning_days      = 45
  }

  pubsub = {
    enabled                      = true
    oldest_message_warning_secs  = 30
    oldest_message_critical_secs = 120
    undelivered_warning          = 500
    undelivered_critical         = 5000
  }

  project_quotas = {
    enabled                      = true
    allocation_warning_threshold = 0.70
  }
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "notification_channel" {
  value = module.monitoring.pubsub_notification_channel_name
}

output "enabled_services" {
  value = module.monitoring.enabled_services
}

output "alert_policy_ids" {
  value = module.monitoring.alert_policy_ids
}

# ── Variables ─────────────────────────────────────────────────────────────────

variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "asia-southeast1"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "gke_cluster_name" {
  type = string
}

variable "alert_topic_name" {
  description = "Name of the existing Pub/Sub topic that receives alert notifications"
  type        = string
}
