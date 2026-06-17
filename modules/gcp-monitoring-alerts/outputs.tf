output "pubsub_notification_channel_name" {
  description = "Resource name of the Pub/Sub notification channel created by this module. Null if no topic was provided."
  value       = var.pubsub_notification_topic != null ? google_monitoring_notification_channel.pubsub[0].name : null
}

output "enabled_services" {
  description = "List of services for which alert policies are enabled."
  value = compact([
    var.gke.enabled ? "gke" : null,
    var.cloud_run.enabled ? "cloud_run" : null,
    var.cloud_sql.enabled ? "cloud_sql" : null,
    var.vpc.enabled ? "vpc" : null,
    var.bigquery.enabled ? "bigquery" : null,
    var.compute_instance.enabled ? "compute_instance" : null,
    var.load_balancer.enabled ? "load_balancer" : null,
    var.pubsub.enabled ? "pubsub" : null,
    var.cloud_armor.enabled ? "cloud_armor" : null,
    var.vertex_ai.enabled ? "vertex_ai" : null,
    var.apigee.enabled ? "apigee" : null,
    var.mig.enabled ? "mig" : null,
    var.cloud_storage.enabled ? "cloud_storage" : null,
    var.gemini.enabled ? "gemini" : null,
    var.ncc.enabled ? "ncc" : null,
    var.secret_manager.enabled ? "secret_manager" : null,
    var.certificate_manager.enabled ? "certificate_manager" : null,
    var.project_quotas.enabled ? "project_quotas" : null,
  ])
}

output "alert_policy_ids" {
  description = "Map of alert policy identifiers to their GCP resource names. Only includes enabled services."
  value = merge(
    # ── GKE ──────────────────────────────────────────────────────────────────
    var.gke.enabled ? {
      gke_node_cpu_warning          = google_monitoring_alert_policy.gke_node_cpu_warning[0].name
      gke_node_cpu_critical         = google_monitoring_alert_policy.gke_node_cpu_critical[0].name
      gke_node_memory_warning       = google_monitoring_alert_policy.gke_node_memory_warning[0].name
      gke_node_memory_critical      = google_monitoring_alert_policy.gke_node_memory_critical[0].name
      gke_container_restart_warning  = google_monitoring_alert_policy.gke_container_restart_warning[0].name
      gke_container_restart_critical = google_monitoring_alert_policy.gke_container_restart_critical[0].name
      gke_container_cpu_warning     = google_monitoring_alert_policy.gke_container_cpu_warning[0].name
      gke_container_cpu_critical    = google_monitoring_alert_policy.gke_container_cpu_critical[0].name
    } : {},

    # ── Cloud Run ─────────────────────────────────────────────────────────────
    var.cloud_run.enabled ? {
      cloud_run_latency_warning      = google_monitoring_alert_policy.cloud_run_latency_warning[0].name
      cloud_run_latency_critical     = google_monitoring_alert_policy.cloud_run_latency_critical[0].name
      cloud_run_error_rate_warning   = google_monitoring_alert_policy.cloud_run_error_rate_warning[0].name
      cloud_run_error_rate_critical  = google_monitoring_alert_policy.cloud_run_error_rate_critical[0].name
      cloud_run_memory_warning       = google_monitoring_alert_policy.cloud_run_memory_warning[0].name
      cloud_run_memory_critical      = google_monitoring_alert_policy.cloud_run_memory_critical[0].name
    } : {},

    # ── Cloud SQL ─────────────────────────────────────────────────────────────
    var.cloud_sql.enabled ? {
      cloud_sql_cpu_warning              = google_monitoring_alert_policy.cloud_sql_cpu_warning[0].name
      cloud_sql_cpu_critical             = google_monitoring_alert_policy.cloud_sql_cpu_critical[0].name
      cloud_sql_memory_warning           = google_monitoring_alert_policy.cloud_sql_memory_warning[0].name
      cloud_sql_memory_critical          = google_monitoring_alert_policy.cloud_sql_memory_critical[0].name
      cloud_sql_disk_warning             = google_monitoring_alert_policy.cloud_sql_disk_warning[0].name
      cloud_sql_disk_critical            = google_monitoring_alert_policy.cloud_sql_disk_critical[0].name
      cloud_sql_connections_warning      = google_monitoring_alert_policy.cloud_sql_connections_warning[0].name
      cloud_sql_connections_critical     = google_monitoring_alert_policy.cloud_sql_connections_critical[0].name
      cloud_sql_replication_lag_warning  = google_monitoring_alert_policy.cloud_sql_replication_lag_warning[0].name
      cloud_sql_replication_lag_critical = google_monitoring_alert_policy.cloud_sql_replication_lag_critical[0].name
    } : {},

    # ── VPC ───────────────────────────────────────────────────────────────────
    var.vpc.enabled ? {
      vpc_subnet_ip_warning    = google_monitoring_alert_policy.vpc_subnet_ip_warning[0].name
      vpc_subnet_ip_critical   = google_monitoring_alert_policy.vpc_subnet_ip_critical[0].name
      vpc_firewall_drops_warning  = google_monitoring_alert_policy.vpc_firewall_drops_warning[0].name
      vpc_firewall_drops_critical = google_monitoring_alert_policy.vpc_firewall_drops_critical[0].name
      vpc_nat_alloc_warning    = google_monitoring_alert_policy.vpc_nat_alloc_warning[0].name
      vpc_nat_alloc_critical   = google_monitoring_alert_policy.vpc_nat_alloc_critical[0].name
    } : {},

    # ── BigQuery ──────────────────────────────────────────────────────────────
    var.bigquery.enabled ? {
      bigquery_slot_warning          = google_monitoring_alert_policy.bigquery_slot_warning[0].name
      bigquery_slot_critical         = google_monitoring_alert_policy.bigquery_slot_critical[0].name
      bigquery_job_duration_warning  = google_monitoring_alert_policy.bigquery_job_duration_warning[0].name
      bigquery_job_duration_critical = google_monitoring_alert_policy.bigquery_job_duration_critical[0].name
      bigquery_table_count_warning   = google_monitoring_alert_policy.bigquery_table_count_warning[0].name
      bigquery_table_count_critical  = google_monitoring_alert_policy.bigquery_table_count_critical[0].name
      bigquery_failed_jobs_warning   = google_monitoring_alert_policy.bigquery_failed_jobs_warning[0].name
      bigquery_failed_jobs_critical  = google_monitoring_alert_policy.bigquery_failed_jobs_critical[0].name
    } : {},

    # ── Compute Instance ──────────────────────────────────────────────────────
    var.compute_instance.enabled ? {
      compute_cpu_warning          = google_monitoring_alert_policy.compute_cpu_warning[0].name
      compute_cpu_critical         = google_monitoring_alert_policy.compute_cpu_critical[0].name
      compute_memory_warning       = google_monitoring_alert_policy.compute_memory_warning[0].name
      compute_memory_critical      = google_monitoring_alert_policy.compute_memory_critical[0].name
      compute_disk_warning         = google_monitoring_alert_policy.compute_disk_warning[0].name
      compute_disk_critical        = google_monitoring_alert_policy.compute_disk_critical[0].name
      compute_disk_throttle_warning  = google_monitoring_alert_policy.compute_disk_throttle_warning[0].name
      compute_disk_throttle_critical = google_monitoring_alert_policy.compute_disk_throttle_critical[0].name
    } : {},

    # ── Load Balancer ─────────────────────────────────────────────────────────
    var.load_balancer.enabled ? {
      lb_error_rate_warning      = google_monitoring_alert_policy.lb_error_rate_warning[0].name
      lb_error_rate_critical     = google_monitoring_alert_policy.lb_error_rate_critical[0].name
      lb_backend_latency_warning  = google_monitoring_alert_policy.lb_backend_latency_warning[0].name
      lb_backend_latency_critical = google_monitoring_alert_policy.lb_backend_latency_critical[0].name
      lb_ssl_expiry_warning      = google_monitoring_alert_policy.lb_ssl_expiry_warning[0].name
      lb_ssl_expiry_critical     = google_monitoring_alert_policy.lb_ssl_expiry_critical[0].name
    } : {},

    # ── Pub/Sub ───────────────────────────────────────────────────────────────
    var.pubsub.enabled ? {
      pubsub_oldest_message_warning  = google_monitoring_alert_policy.pubsub_oldest_message_warning[0].name
      pubsub_oldest_message_critical = google_monitoring_alert_policy.pubsub_oldest_message_critical[0].name
      pubsub_undelivered_warning     = google_monitoring_alert_policy.pubsub_undelivered_warning[0].name
      pubsub_undelivered_critical    = google_monitoring_alert_policy.pubsub_undelivered_critical[0].name
      pubsub_dead_letter_warning     = google_monitoring_alert_policy.pubsub_dead_letter_warning[0].name
      pubsub_dead_letter_critical    = google_monitoring_alert_policy.pubsub_dead_letter_critical[0].name
      pubsub_publish_errors_warning  = google_monitoring_alert_policy.pubsub_publish_errors_warning[0].name
      pubsub_publish_errors_critical = google_monitoring_alert_policy.pubsub_publish_errors_critical[0].name
    } : {},

    # ── Cloud Armor ───────────────────────────────────────────────────────────
    var.cloud_armor.enabled ? {
      armor_denied_requests_warning  = google_monitoring_alert_policy.armor_denied_requests_warning[0].name
      armor_denied_requests_critical = google_monitoring_alert_policy.armor_denied_requests_critical[0].name
      armor_allowed_spike_warning    = google_monitoring_alert_policy.armor_allowed_spike_warning[0].name
    } : {},

    # ── Vertex AI ─────────────────────────────────────────────────────────────
    var.vertex_ai.enabled ? {
      vertex_prediction_errors_warning   = google_monitoring_alert_policy.vertex_prediction_errors_warning[0].name
      vertex_prediction_errors_critical  = google_monitoring_alert_policy.vertex_prediction_errors_critical[0].name
      vertex_prediction_latency_warning  = google_monitoring_alert_policy.vertex_prediction_latency_warning[0].name
      vertex_prediction_latency_critical = google_monitoring_alert_policy.vertex_prediction_latency_critical[0].name
      vertex_endpoint_cpu_warning        = google_monitoring_alert_policy.vertex_endpoint_cpu_warning[0].name
      vertex_endpoint_cpu_critical       = google_monitoring_alert_policy.vertex_endpoint_cpu_critical[0].name
      vertex_pipeline_failures_warning   = google_monitoring_alert_policy.vertex_pipeline_failures_warning[0].name
      vertex_pipeline_failures_critical  = google_monitoring_alert_policy.vertex_pipeline_failures_critical[0].name
    } : {},

    # ── Apigee ────────────────────────────────────────────────────────────────
    var.apigee.enabled ? {
      apigee_error_rate_warning       = google_monitoring_alert_policy.apigee_error_rate_warning[0].name
      apigee_error_rate_critical      = google_monitoring_alert_policy.apigee_error_rate_critical[0].name
      apigee_latency_warning          = google_monitoring_alert_policy.apigee_latency_warning[0].name
      apigee_latency_critical         = google_monitoring_alert_policy.apigee_latency_critical[0].name
      apigee_quota_violations_warning  = google_monitoring_alert_policy.apigee_quota_violations_warning[0].name
      apigee_quota_violations_critical = google_monitoring_alert_policy.apigee_quota_violations_critical[0].name
    } : {},

    # ── MIG ───────────────────────────────────────────────────────────────────
    var.mig.enabled ? {
      mig_autoscaler_warning           = google_monitoring_alert_policy.mig_autoscaler_warning[0].name
      mig_autoscaler_critical          = google_monitoring_alert_policy.mig_autoscaler_critical[0].name
      mig_unhealthy_instances_warning  = google_monitoring_alert_policy.mig_unhealthy_instances_warning[0].name
      mig_unhealthy_instances_critical = google_monitoring_alert_policy.mig_unhealthy_instances_critical[0].name
    } : {},

    # ── Cloud Storage ─────────────────────────────────────────────────────────
    var.cloud_storage.enabled ? merge(
      {
        gcs_error_count_warning        = google_monitoring_alert_policy.gcs_error_count_warning[0].name
        gcs_error_count_critical       = google_monitoring_alert_policy.gcs_error_count_critical[0].name
        gcs_replication_lag_warning    = google_monitoring_alert_policy.gcs_replication_lag_warning[0].name
        gcs_replication_lag_critical   = google_monitoring_alert_policy.gcs_replication_lag_critical[0].name
      },
      var.cloud_storage.total_bytes_warning != null ? {
        gcs_total_bytes_warning = google_monitoring_alert_policy.gcs_total_bytes_warning[0].name
      } : {},
      var.cloud_storage.total_bytes_critical != null ? {
        gcs_total_bytes_critical = google_monitoring_alert_policy.gcs_total_bytes_critical[0].name
      } : {},
    ) : {},

    # ── Gemini ────────────────────────────────────────────────────────────────
    var.gemini.enabled ? {
      gemini_error_rate_warning  = google_monitoring_alert_policy.gemini_error_rate_warning[0].name
      gemini_error_rate_critical = google_monitoring_alert_policy.gemini_error_rate_critical[0].name
      gemini_quota_warning       = google_monitoring_alert_policy.gemini_quota_warning[0].name
      gemini_quota_critical      = google_monitoring_alert_policy.gemini_quota_critical[0].name
    } : {},

    # ── NCC ───────────────────────────────────────────────────────────────────
    var.ncc.enabled ? {
      ncc_spoke_state_warning      = google_monitoring_alert_policy.ncc_spoke_state_warning[0].name
      ncc_hub_throughput_warning   = google_monitoring_alert_policy.ncc_hub_throughput_warning[0].name
      ncc_hub_throughput_critical  = google_monitoring_alert_policy.ncc_hub_throughput_critical[0].name
      ncc_bgp_session_down         = google_monitoring_alert_policy.ncc_bgp_session_down[0].name
    } : {},

    # ── Secret Manager ────────────────────────────────────────────────────────
    var.secret_manager.enabled ? {
      secret_access_denied_warning    = google_monitoring_alert_policy.secret_access_denied_warning[0].name
      secret_access_denied_critical   = google_monitoring_alert_policy.secret_access_denied_critical[0].name
      secret_version_destroyed_warning = google_monitoring_alert_policy.secret_version_destroyed_warning[0].name
    } : {},

    # ── Certificate Manager ───────────────────────────────────────────────────
    var.certificate_manager.enabled ? {
      cert_expiry_warning          = google_monitoring_alert_policy.cert_expiry_warning[0].name
      cert_expiry_critical         = google_monitoring_alert_policy.cert_expiry_critical[0].name
      cert_provisioning_failure    = google_monitoring_alert_policy.cert_provisioning_failure[0].name
    } : {},

    # ── Project Quotas ────────────────────────────────────────────────────────
    var.project_quotas.enabled ? {
      quota_allocation_warning  = google_monitoring_alert_policy.quota_allocation_warning[0].name
      quota_allocation_critical = google_monitoring_alert_policy.quota_allocation_critical[0].name
      quota_rate_warning        = google_monitoring_alert_policy.quota_rate_warning[0].name
      quota_rate_critical       = google_monitoring_alert_policy.quota_rate_critical[0].name
    } : {},
  )
}
