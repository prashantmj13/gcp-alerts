# Minimal example: enable GKE + VPC alerts with zero custom configuration.
# All thresholds use module defaults. Alerts are delivered to a Pub/Sub topic
# which forwards to a Cloud Run function for routing.

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
  region  = "asia-southeast1"
}

# ── Monitoring Module ─────────────────────────────────────────────────────────
# Source from GitHub — pin to a release tag for reproducible builds.
# For Bitbucket: git::https://bitbucket.org/YOUR_ORG/YOUR_REPO.git//modules/gcp-monitoring-alerts?ref=v1.0.0
# For local dev:  ../../modules/gcp-monitoring-alerts

module "monitoring" {
  source = "git::https://github.com/YOUR_ORG/YOUR_REPO.git//modules/gcp-monitoring-alerts?ref=v1.0.0"

  project_id = var.project_id

  # The module creates a Cloud Monitoring Pub/Sub notification channel pointing
  # to this topic. A Cloud Run function with a push subscription processes alerts.
  pubsub_notification_topic = "projects/${var.project_id}/topics/${var.alert_topic_name}"

  default_labels = {
    team = "platform"
    env  = "prod"
  }

  gke = { enabled = true }
  vpc = { enabled = true }
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
  description = "GCP project ID"
  type        = string
}

variable "alert_topic_name" {
  description = "Name of the existing Pub/Sub topic that receives alert notifications"
  type        = string
}
