variable "project_id" {
  description = "GCP project ID where alert policies will be created."
  type        = string
}

variable "pubsub_notification_topic" {
  description = <<-EOT
    Pub/Sub topic resource name for alert notifications.
    The module creates a Cloud Monitoring notification channel of type 'pubsub'
    pointing to this topic. Consumers subscribe to the topic to receive alerts.
    Format: projects/{project_id}/topics/{topic_name}
    Leave null to create alert policies without a notification channel (alerts
    are still visible in the Cloud Monitoring console).
  EOT
  type    = string
  default = null
}

variable "pubsub_notification_channel_display_name" {
  description = "Display name for the Pub/Sub notification channel created by this module."
  type        = string
  default     = "GCP Monitoring Alerts - Pub/Sub"
}

variable "default_labels" {
  description = "Labels applied to every alert policy. Merged with per-service labels."
  type        = map(string)
  default     = {}
}

variable "alert_documentation_prefix" {
  description = "URL prefix prepended to runbook paths in alert policy documentation."
  type        = string
  default     = ""
}

# ─── GKE ─────────────────────────────────────────────────────────────────────

variable "gke" {
  description = "GKE cluster monitoring configuration."
  type = object({
    enabled                          = optional(bool, false)
    cluster_name                     = optional(string, null)
    location                         = optional(string, null)
    labels                           = optional(map(string), {})
    node_cpu_warning_threshold       = optional(number, 0.75)
    node_cpu_critical_threshold      = optional(number, 0.90)
    node_memory_warning_threshold    = optional(number, 0.80)
    node_memory_critical_threshold   = optional(number, 0.90)
    container_restart_warning        = optional(number, 3)
    container_restart_critical       = optional(number, 10)
    container_cpu_warning_threshold  = optional(number, 0.80)
    container_cpu_critical_threshold = optional(number, 0.95)
    duration_warning_secs            = optional(number, 300)
    duration_critical_secs           = optional(number, 120)
  })
  default = {}
}

# ─── Cloud Run ───────────────────────────────────────────────────────────────

variable "cloud_run" {
  description = "Cloud Run monitoring configuration."
  type = object({
    enabled                       = optional(bool, false)
    service_name                  = optional(string, null)
    location                      = optional(string, null)
    labels                        = optional(map(string), {})
    latency_p99_warning_ms        = optional(number, 2000)
    latency_p99_critical_ms       = optional(number, 5000)
    error_rate_warning_threshold  = optional(number, 0.01)
    error_rate_critical_threshold = optional(number, 0.05)
    memory_warning_threshold      = optional(number, 0.80)
    memory_critical_threshold     = optional(number, 0.95)
    duration_warning_secs         = optional(number, 300)
    duration_critical_secs        = optional(number, 60)
  })
  default = {}
}

# ─── Cloud SQL ───────────────────────────────────────────────────────────────

variable "cloud_sql" {
  description = "Cloud SQL instance monitoring configuration."
  type = object({
    enabled                        = optional(bool, false)
    database_id_filter             = optional(string, null)
    labels                         = optional(map(string), {})
    cpu_warning_threshold          = optional(number, 0.75)
    cpu_critical_threshold         = optional(number, 0.90)
    memory_warning_threshold       = optional(number, 0.80)
    memory_critical_threshold      = optional(number, 0.90)
    disk_warning_threshold         = optional(number, 0.75)
    disk_critical_threshold        = optional(number, 0.85)
    connections_warning_threshold  = optional(number, 0.80)
    connections_critical_threshold = optional(number, 0.90)
    replication_lag_warning_secs   = optional(number, 30)
    replication_lag_critical_secs  = optional(number, 120)
    duration_warning_secs          = optional(number, 300)
    duration_critical_secs         = optional(number, 120)
  })
  default = {}
}

# ─── VPC / Subnet ────────────────────────────────────────────────────────────

variable "vpc" {
  description = "VPC and Subnet monitoring configuration."
  type = object({
    enabled                      = optional(bool, false)
    subnetwork_name              = optional(string, null)
    labels                       = optional(map(string), {})
    subnet_ip_warning_threshold  = optional(number, 0.70)
    subnet_ip_critical_threshold = optional(number, 0.85)
    firewall_drop_warning        = optional(number, 100)
    firewall_drop_critical       = optional(number, 500)
    nat_alloc_fail_warning       = optional(number, 1)
    nat_alloc_fail_critical      = optional(number, 10)
    duration_warning_secs        = optional(number, 300)
    duration_critical_secs       = optional(number, 120)
  })
  default = {}
}

# ─── BigQuery ────────────────────────────────────────────────────────────────

variable "bigquery" {
  description = "BigQuery monitoring configuration."
  type = object({
    enabled                     = optional(bool, false)
    labels                      = optional(map(string), {})
    slot_utilization_warning    = optional(number, 0.80)
    slot_utilization_critical   = optional(number, 0.95)
    job_execution_warning_secs  = optional(number, 600)
    job_execution_critical_secs = optional(number, 1800)
    table_count_warning         = optional(number, 8000)
    table_count_critical        = optional(number, 9500)
    failed_jobs_warning         = optional(number, 5)
    failed_jobs_critical        = optional(number, 20)
    duration_warning_secs       = optional(number, 300)
    duration_critical_secs      = optional(number, 120)
  })
  default = {}
}

# ─── Compute Instance ────────────────────────────────────────────────────────

variable "compute_instance" {
  description = "Compute Engine instance monitoring configuration."
  type = object({
    enabled                   = optional(bool, false)
    instance_name_filter      = optional(string, null)
    labels                    = optional(map(string), {})
    cpu_warning_threshold     = optional(number, 0.75)
    cpu_critical_threshold    = optional(number, 0.90)
    memory_warning_threshold  = optional(number, 0.80)
    memory_critical_threshold = optional(number, 0.90)
    disk_warning_threshold    = optional(number, 0.80)
    disk_critical_threshold   = optional(number, 0.90)
    disk_io_warning           = optional(number, 100)
    disk_io_critical          = optional(number, 500)
    duration_warning_secs     = optional(number, 300)
    duration_critical_secs    = optional(number, 120)
  })
  default = {}
}

# ─── Load Balancer ───────────────────────────────────────────────────────────

variable "load_balancer" {
  description = "HTTP(S) Load Balancer monitoring configuration."
  type = object({
    enabled                       = optional(bool, false)
    forwarding_rule_filter        = optional(string, null)
    labels                        = optional(map(string), {})
    error_rate_warning_threshold  = optional(number, 0.01)
    error_rate_critical_threshold = optional(number, 0.05)
    latency_p95_warning_ms        = optional(number, 1000)
    latency_p95_critical_ms       = optional(number, 3000)
    ssl_expiry_warning_days       = optional(number, 30)
    ssl_expiry_critical_days      = optional(number, 7)
    duration_warning_secs         = optional(number, 300)
    duration_critical_secs        = optional(number, 120)
  })
  default = {}
}

# ─── Pub/Sub ─────────────────────────────────────────────────────────────────

variable "pubsub" {
  description = "Pub/Sub monitoring configuration."
  type = object({
    enabled                       = optional(bool, false)
    subscription_filter           = optional(string, null)
    labels                        = optional(map(string), {})
    oldest_message_warning_secs   = optional(number, 60)
    oldest_message_critical_secs  = optional(number, 300)
    undelivered_warning           = optional(number, 1000)
    undelivered_critical          = optional(number, 10000)
    dead_letter_warning           = optional(number, 10)
    dead_letter_critical          = optional(number, 100)
    publish_error_warning         = optional(number, 10)
    publish_error_critical        = optional(number, 50)
    duration_warning_secs         = optional(number, 300)
    duration_critical_secs        = optional(number, 120)
  })
  default = {}
}

# ─── Cloud Armor ─────────────────────────────────────────────────────────────

variable "cloud_armor" {
  description = "Cloud Armor security policy monitoring configuration."
  type = object({
    enabled                  = optional(bool, false)
    security_policy_filter   = optional(string, null)
    labels                   = optional(map(string), {})
    denied_requests_warning  = optional(number, 100)
    denied_requests_critical = optional(number, 1000)
    duration_warning_secs    = optional(number, 300)
    duration_critical_secs   = optional(number, 60)
  })
  default = {}
}

# ─── Vertex AI ───────────────────────────────────────────────────────────────

variable "vertex_ai" {
  description = "Vertex AI monitoring configuration."
  type = object({
    enabled                   = optional(bool, false)
    endpoint_filter           = optional(string, null)
    labels                    = optional(map(string), {})
    error_count_warning       = optional(number, 10)
    error_count_critical      = optional(number, 50)
    latency_p99_warning_ms    = optional(number, 2000)
    latency_p99_critical_ms   = optional(number, 5000)
    cpu_warning_threshold     = optional(number, 0.75)
    cpu_critical_threshold    = optional(number, 0.90)
    pipeline_fail_warning     = optional(number, 1)
    pipeline_fail_critical    = optional(number, 5)
    duration_warning_secs     = optional(number, 300)
    duration_critical_secs    = optional(number, 120)
  })
  default = {}
}

# ─── Apigee ──────────────────────────────────────────────────────────────────

variable "apigee" {
  description = "Apigee API Gateway monitoring configuration."
  type = object({
    enabled                         = optional(bool, false)
    proxy_name_filter               = optional(string, null)
    labels                          = optional(map(string), {})
    error_rate_warning_threshold    = optional(number, 0.01)
    error_rate_critical_threshold   = optional(number, 0.05)
    latency_p99_warning_ms          = optional(number, 2000)
    latency_p99_critical_ms         = optional(number, 5000)
    target_error_warning_threshold  = optional(number, 0.05)
    target_error_critical_threshold = optional(number, 0.15)
    quota_violation_warning         = optional(number, 100)
    quota_violation_critical        = optional(number, 500)
    duration_warning_secs           = optional(number, 300)
    duration_critical_secs          = optional(number, 120)
  })
  default = {}
}

# ─── Managed Instance Groups ─────────────────────────────────────────────────

variable "mig" {
  description = "Managed Instance Group monitoring configuration."
  type = object({
    enabled                         = optional(bool, false)
    instance_group_filter           = optional(string, null)
    labels                          = optional(map(string), {})
    autoscaler_utilization_warning  = optional(number, 0.80)
    autoscaler_utilization_critical = optional(number, 0.95)
    unhealthy_ratio_warning         = optional(number, 0.10)
    unhealthy_ratio_critical        = optional(number, 0.25)
    duration_warning_secs           = optional(number, 300)
    duration_critical_secs          = optional(number, 120)
  })
  default = {}
}

# ─── Cloud Storage ───────────────────────────────────────────────────────────

variable "cloud_storage" {
  description = "Cloud Storage monitoring configuration."
  type = object({
    enabled                       = optional(bool, false)
    bucket_name_filter            = optional(string, null)
    labels                        = optional(map(string), {})
    error_count_warning           = optional(number, 50)
    error_count_critical          = optional(number, 200)
    total_bytes_warning           = optional(number, null)
    total_bytes_critical          = optional(number, null)
    replication_lag_warning_secs  = optional(number, 60)
    replication_lag_critical_secs = optional(number, 300)
    duration_warning_secs         = optional(number, 300)
    duration_critical_secs        = optional(number, 120)
  })
  default = {}
}

# ─── Gemini Enterprise ───────────────────────────────────────────────────────

variable "gemini" {
  description = "Gemini Enterprise (Cloud AI Companion API) monitoring configuration."
  type = object({
    enabled                       = optional(bool, false)
    labels                        = optional(map(string), {})
    error_rate_warning_threshold  = optional(number, 0.05)
    error_rate_critical_threshold = optional(number, 0.15)
    quota_warning_threshold       = optional(number, 0.80)
    quota_critical_threshold      = optional(number, 0.95)
    duration_warning_secs         = optional(number, 300)
    duration_critical_secs        = optional(number, 120)
  })
  default = {}
}

# ─── NCC Spokes ──────────────────────────────────────────────────────────────

variable "ncc" {
  description = "Network Connectivity Center Hub and Spoke monitoring configuration."
  type = object({
    enabled                       = optional(bool, false)
    hub_name_filter               = optional(string, null)
    labels                        = optional(map(string), {})
    throughput_warning_threshold  = optional(number, 0.70)
    throughput_critical_threshold = optional(number, 0.85)
    duration_warning_secs         = optional(number, 300)
    duration_critical_secs        = optional(number, 120)
  })
  default = {}
}

# ─── Secret Manager ──────────────────────────────────────────────────────────

variable "secret_manager" {
  description = "Secret Manager monitoring configuration."
  type = object({
    enabled                 = optional(bool, false)
    labels                  = optional(map(string), {})
    access_denied_warning   = optional(number, 3)
    access_denied_critical  = optional(number, 10)
    duration_warning_secs   = optional(number, 3600)
    duration_critical_secs  = optional(number, 3600)
  })
  default = {}
}

# ─── Certificate Manager ─────────────────────────────────────────────────────

variable "certificate_manager" {
  description = "Certificate Manager monitoring configuration."
  type = object({
    enabled               = optional(bool, false)
    labels                = optional(map(string), {})
    expiry_warning_days   = optional(number, 30)
    expiry_critical_days  = optional(number, 7)
    duration_warning_secs = optional(number, 300)
    duration_critical_secs = optional(number, 120)
  })
  default = {}
}

# ─── GCP Project Quotas ──────────────────────────────────────────────────────

variable "project_quotas" {
  description = "GCP project quota monitoring configuration."
  type = object({
    enabled                       = optional(bool, false)
    labels                        = optional(map(string), {})
    allocation_warning_threshold  = optional(number, 0.75)
    allocation_critical_threshold = optional(number, 0.90)
    rate_warning_threshold        = optional(number, 0.80)
    rate_critical_threshold       = optional(number, 0.95)
    duration_warning_secs         = optional(number, 300)
    duration_critical_secs        = optional(number, 120)
  })
  default = {}
}
