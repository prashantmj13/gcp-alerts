# GCP Infrastructure Monitoring Alerts — Terraform Module

A reusable Terraform module that provisions **GCP Cloud Monitoring alert policies** for 19 GCP services. Teams enable only the services they use; every alert has sensible defaults so minimal configuration is required.

---

## What This Module Provisions

- **Alert policies** — one per metric per severity (warning + critical) for each enabled service
- **Notification channels** — Pub/Sub and/or email channels, or attach pre-existing channels
- **Log-based metrics** — for services without native Cloud Monitoring metrics (Secret Manager, BigQuery jobs, NCC, Certificate Manager)

Alerts fire → notification channels → Pub/Sub topic → Cloud Run function → Moogsoft (on-prem ticketing)

---

## Services Covered

| # | Service | What Is Monitored |
|---|---------|-------------------|
| 1 | GKE | Node CPU/memory, container restarts, container CPU limits |
| 2 | Cloud Run | Request latency P99, 5xx error rate, container memory |
| 3 | Cloud SQL | CPU, memory, disk, connections, replication lag |
| 4 | VPC / Subnet | Subnet IP utilisation (primary + optional secondary), firewall drops, NAT failures |
| 5 | BigQuery | Slot utilisation, job duration, table count, failed jobs |
| 6 | Compute Engine | CPU, memory, disk, disk I/O throttle (requires Ops Agent) |
| 7 | Load Balancer | 5xx error rate, backend latency P95, SSL certificate expiry |
| 8 | Pub/Sub | Oldest unacked message age, undelivered count, dead letter depth, publish errors |
| 9 | Cloud Armor | Denied request rate, allowed traffic spike |
| 10 | Vertex AI | Prediction errors/latency, endpoint CPU, pipeline failures |
| 11 | Apigee | 5xx error rate, proxy latency P99, quota violations |
| 12 | Managed Instance Groups | Autoscaler utilisation, unhealthy instance ratio |
| 13 | Cloud Storage | API errors, storage size (optional), replication lag |
| 14 | Gemini Enterprise | API error rate, quota utilisation |
| 15 | NCC Spokes | Spoke state changes, hub throughput, BGP sessions |
| 16 | Secret Manager | Access denied events, secret version destroyed |
| 17 | Certificate Manager | Certificate expiry, provisioning failures |
| 18 | GCP Project Quotas | Allocation quota usage, rate quota usage |

---

## Threshold Levels

All percentage-based alerts use a standard two-level threshold:

| Severity | Default | Duration before firing | Action |
|---|---|---|---|
| **Warning** | **80%** | 5 minutes | Investigate |
| **Critical** | **90%** | 1–2 minutes | Immediate response |

Non-percentage thresholds (latency, counts, time-based) vary per service and are listed in the [Service Variables](#service-variables) section. All thresholds can be overridden per service.

---

## Prerequisites

| Requirement | Detail |
|---|---|
| Terraform | `>= 1.3.0` |
| Google Provider | `>= 5.0, < 7.99` |
| GCP APIs | `monitoring.googleapis.com` and `logging.googleapis.com` must be enabled |
| IAM | Terraform SA needs `roles/monitoring.alertPolicyEditor`, `roles/monitoring.notificationChannelEditor`, `roles/logging.admin` |
| Pub/Sub topic | Must already exist. The module creates the notification channel, not the topic. |
| Ops Agent | Required on Compute Engine instances for memory and disk metrics. |
| GKE System Metrics | Must be enabled on the cluster for node/container metrics. |

---

## How to Use the Module

### Source URL

```hcl
# GitHub
source = "git::https://github.com/YOUR_ORG/YOUR_REPO.git?ref=v1.0.0"

# Bitbucket
source = "git::https://bitbucket.org/YOUR_ORG/YOUR_REPO.git?ref=v1.0.0"

# SSH (private repos)
source = "git::ssh://git@bitbucket.org/YOUR_ORG/YOUR_REPO.git?ref=v1.0.0"

# Local development
source = "../../"
```

Pin to a release tag (`?ref=v1.0.0`) for reproducible builds. Avoid `?ref=main`.

### Minimal usage

All thresholds have defaults — passing `{ enabled = true }` is enough to get started:

```hcl
module "monitoring" {
  source     = "git::https://github.com/YOUR_ORG/YOUR_REPO.git?ref=v1.0.0"
  project_id = "my-project-id"

  pubsub_notification_topic = "projects/my-project-id/topics/gcp-monitoring-alerts"

  default_labels = {
    team = "platform"
    env  = "prod"
  }

  gke       = { enabled = true }
  cloud_sql = { enabled = true }
  vpc       = { enabled = true }
}
```

### Override thresholds

Only specify the values you want to change:

```hcl
gke = {
  enabled                    = true
  cluster_name               = "prod-cluster"
  node_cpu_warning_threshold = 0.70
  container_restart_warning  = 2
  duration_critical_secs     = 60
}
```

### Add runbook links

```hcl
alert_documentation_prefix = "https://wiki.example.com"
# Each alert's documentation will include: https://wiki.example.com/runbooks/<service>
```

---

## Notification Channels

Three options — use any combination. All configured channels receive every alert.

| Option | Variable | Description |
|---|---|---|
| Pub/Sub | `pubsub_notification_topic` | Module creates a channel pointing to an existing topic |
| Email | `email_notification_addresses` | Module creates one channel per address |
| Pre-existing | `existing_notification_channel_names` | Pass resource names of channels managed outside this module |

```hcl
# Pub/Sub only
pubsub_notification_topic = "projects/my-project/topics/gcp-monitoring-alerts"

# Email only
email_notification_addresses = ["platform-alerts@example.com", "sre-oncall@example.com"]

# Pre-existing channel (find with: gcloud monitoring channels list --project=PROJECT)
existing_notification_channel_names = ["projects/my-project/notificationChannels/1234567890"]

# Any combination — all channels receive every alert
pubsub_notification_topic           = "projects/my-project/topics/gcp-monitoring-alerts"
existing_notification_channel_names = ["projects/my-project/notificationChannels/1234567890"]
```

---

## Input Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `project_id` | `string` | **required** | GCP project ID |
| `pubsub_notification_topic` | `string` | `null` | Pub/Sub topic resource name. Format: `projects/{project}/topics/{topic}` |
| `pubsub_notification_channel_display_name` | `string` | `"GCP Monitoring Alerts - Pub/Sub"` | Display name for the Pub/Sub channel |
| `email_notification_addresses` | `list(string)` | `[]` | Email addresses to notify |
| `existing_notification_channel_names` | `list(string)` | `[]` | Pre-existing channel resource names. Format: `projects/{project}/notificationChannels/{id}` |
| `default_labels` | `map(string)` | `{}` | Labels applied to every alert policy |
| `alert_documentation_prefix` | `string` | `""` | URL prefix prepended to runbook links in alert documentation |

---

## Service Variables

Each service accepts an object with `optional()` fields. The `enabled` field defaults to `false` — pass `{ enabled = true }` to activate with all defaults.

### `gke`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable GKE alerts |
| `cluster_name` | `null` | Scope to a specific cluster (null = all) |
| `location` | `null` | Scope to a specific region (null = all) |
| `node_cpu_warning_threshold` | `0.80` | Node CPU warning (0–1) |
| `node_cpu_critical_threshold` | `0.90` | Node CPU critical (0–1) |
| `node_memory_warning_threshold` | `0.80` | Node memory warning (0–1) |
| `node_memory_critical_threshold` | `0.90` | Node memory critical (0–1) |
| `container_restart_warning` | `3` | Container restarts / 5 min — warning |
| `container_restart_critical` | `10` | Container restarts / 5 min — critical |
| `container_cpu_warning_threshold` | `0.80` | Container CPU limit utilisation warning (0–1) |
| `container_cpu_critical_threshold` | `0.90` | Container CPU limit utilisation critical (0–1) |
| `duration_warning_secs` | `300` | Seconds before warning fires |
| `duration_critical_secs` | `120` | Seconds before critical fires |

### `cloud_run`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Cloud Run alerts |
| `service_name` | `null` | Scope to a specific service (null = all) |
| `location` | `null` | Scope to a specific region |
| `latency_p99_warning_ms` | `2000` | P99 latency warning (ms) |
| `latency_p99_critical_ms` | `5000` | P99 latency critical (ms) |
| `error_rate_warning_threshold` | `0.01` | 5xx error rate warning (0–1) |
| `error_rate_critical_threshold` | `0.05` | 5xx error rate critical (0–1) |
| `memory_warning_threshold` | `0.80` | Memory utilisation warning (0–1) |
| `memory_critical_threshold` | `0.90` | Memory utilisation critical (0–1) |
| `duration_warning_secs` | `300` | Seconds before warning fires |
| `duration_critical_secs` | `60` | Seconds before critical fires |

### `cloud_sql`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Cloud SQL alerts |
| `database_id_filter` | `null` | Regex filter on database ID (null = all instances) |
| `cpu_warning_threshold` | `0.80` | CPU warning (0–1) |
| `cpu_critical_threshold` | `0.90` | CPU critical (0–1) |
| `memory_warning_threshold` | `0.80` | Memory warning (0–1) |
| `memory_critical_threshold` | `0.90` | Memory critical (0–1) |
| `disk_warning_threshold` | `0.80` | Disk warning (0–1) |
| `disk_critical_threshold` | `0.90` | Disk critical (0–1) |
| `connections_warning_threshold` | `0.80` | Connection count warning ratio (0–1) |
| `connections_critical_threshold` | `0.90` | Connection count critical ratio (0–1) |
| `replication_lag_warning_secs` | `30` | Replica lag warning (seconds) |
| `replication_lag_critical_secs` | `120` | Replica lag critical (seconds) |
| `duration_warning_secs` | `300` | Seconds before warning fires |
| `duration_critical_secs` | `120` | Seconds before critical fires |

### `vpc`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable VPC / Subnet alerts |
| `subnetwork_name` | `null` | Scope to a specific subnetwork (null = all) |
| `subnet_ip_warning_threshold` | `0.80` | Primary range IP utilisation warning (0–1) |
| `subnet_ip_critical_threshold` | `0.90` | Primary range IP utilisation critical (0–1) |
| `enable_secondary_range_alerts` | `false` | Enable secondary range alerts (GKE pod/service CIDRs) |
| `secondary_subnet_ip_warning_threshold` | `0.80` | Secondary range IP utilisation warning (0–1) |
| `secondary_subnet_ip_critical_threshold` | `0.90` | Secondary range IP utilisation critical (0–1) |
| `firewall_drop_warning` | `100` | Firewall dropped packets/min — warning |
| `firewall_drop_critical` | `500` | Firewall dropped packets/min — critical |
| `nat_alloc_fail_warning` | `1` | NAT port allocation failures — warning |
| `nat_alloc_fail_critical` | `10` | NAT port allocation failures — critical |
| `duration_warning_secs` | `300` | Seconds before warning fires |
| `duration_critical_secs` | `120` | Seconds before critical fires |

### `bigquery`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable BigQuery alerts |
| `slot_utilization_warning` | `0.80` | Slot utilisation warning (0–1) |
| `slot_utilization_critical` | `0.90` | Slot utilisation critical (0–1) |
| `job_execution_warning_secs` | `600` | Job execution time warning (seconds) |
| `job_execution_critical_secs` | `1800` | Job execution time critical (seconds) |
| `table_count_warning` | `8000` | Tables per dataset warning (limit is 10,000) |
| `table_count_critical` | `9500` | Tables per dataset critical |
| `failed_jobs_warning` | `5` | Failed jobs/hour — warning |
| `failed_jobs_critical` | `20` | Failed jobs/hour — critical |
| `duration_warning_secs` | `300` | Seconds before warning fires |
| `duration_critical_secs` | `120` | Seconds before critical fires |

### `compute_instance`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Compute Engine alerts |
| `instance_name_filter` | `null` | Regex filter on instance name |
| `cpu_warning_threshold` | `0.80` | CPU warning (0–1) |
| `cpu_critical_threshold` | `0.90` | CPU critical (0–1) |
| `memory_warning_threshold` | `0.80` | Memory warning (0–1) — requires Ops Agent |
| `memory_critical_threshold` | `0.90` | Memory critical (0–1) — requires Ops Agent |
| `disk_warning_threshold` | `0.80` | Disk warning (0–1) — requires Ops Agent |
| `disk_critical_threshold` | `0.90` | Disk critical (0–1) — requires Ops Agent |
| `disk_io_warning` | `100` | Throttled disk ops/min — warning |
| `disk_io_critical` | `500` | Throttled disk ops/min — critical |
| `duration_warning_secs` | `300` | Seconds before warning fires |
| `duration_critical_secs` | `120` | Seconds before critical fires |

### `load_balancer`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable HTTP(S) Load Balancer alerts |
| `forwarding_rule_filter` | `null` | Regex filter on forwarding rule name |
| `error_rate_warning_threshold` | `0.01` | 5xx error rate warning (0–1) |
| `error_rate_critical_threshold` | `0.05` | 5xx error rate critical (0–1) |
| `latency_p95_warning_ms` | `1000` | Backend P95 latency warning (ms) |
| `latency_p95_critical_ms` | `3000` | Backend P95 latency critical (ms) |
| `ssl_expiry_warning_days` | `30` | SSL cert expiry warning (days remaining) |
| `ssl_expiry_critical_days` | `7` | SSL cert expiry critical (days remaining) |
| `duration_warning_secs` | `300` | Seconds before warning fires |
| `duration_critical_secs` | `120` | Seconds before critical fires |

### `pubsub`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Pub/Sub alerts |
| `subscription_filter` | `null` | Regex filter on subscription ID |
| `oldest_message_warning_secs` | `60` | Oldest unacked message age — warning |
| `oldest_message_critical_secs` | `300` | Oldest unacked message age — critical |
| `undelivered_warning` | `1000` | Undelivered message count — warning |
| `undelivered_critical` | `10000` | Undelivered message count — critical |
| `dead_letter_warning` | `10` | Dead letter queue depth — warning |
| `dead_letter_critical` | `100` | Dead letter queue depth — critical |
| `publish_error_warning` | `10` | Publish errors/min — warning |
| `publish_error_critical` | `50` | Publish errors/min — critical |
| `duration_warning_secs` | `300` | Seconds before warning fires |
| `duration_critical_secs` | `120` | Seconds before critical fires |

### `cloud_armor`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Cloud Armor alerts |
| `security_policy_filter` | `null` | Regex filter on security policy name |
| `denied_requests_warning` | `100` | Denied requests/min — warning |
| `denied_requests_critical` | `1000` | Denied requests/min — critical |
| `duration_warning_secs` | `300` | Seconds before warning fires |
| `duration_critical_secs` | `60` | Seconds before critical fires |

### `vertex_ai`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Vertex AI alerts |
| `endpoint_filter` | `null` | Regex filter on endpoint ID |
| `error_count_warning` | `10` | Prediction errors/min — warning |
| `error_count_critical` | `50` | Prediction errors/min — critical |
| `latency_p99_warning_ms` | `2000` | Prediction P99 latency warning (ms) |
| `latency_p99_critical_ms` | `5000` | Prediction P99 latency critical (ms) |
| `cpu_warning_threshold` | `0.80` | Endpoint CPU warning (0–1) |
| `cpu_critical_threshold` | `0.90` | Endpoint CPU critical (0–1) |
| `pipeline_fail_warning` | `1` | Pipeline failures — warning |
| `pipeline_fail_critical` | `5` | Pipeline failures — critical |
| `duration_warning_secs` | `300` | Seconds before warning fires |
| `duration_critical_secs` | `120` | Seconds before critical fires |

### `apigee`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Apigee alerts |
| `proxy_name_filter` | `null` | Regex filter on proxy name |
| `error_rate_warning_threshold` | `0.01` | 5xx error rate warning (0–1) |
| `error_rate_critical_threshold` | `0.05` | 5xx error rate critical (0–1) |
| `latency_p99_warning_ms` | `2000` | Proxy P99 latency warning (ms) |
| `latency_p99_critical_ms` | `5000` | Proxy P99 latency critical (ms) |
| `quota_violation_warning` | `100` | Quota violations/hour — warning |
| `quota_violation_critical` | `500` | Quota violations/hour — critical |
| `duration_warning_secs` | `300` | Seconds before warning fires |
| `duration_critical_secs` | `120` | Seconds before critical fires |

### `mig`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Managed Instance Group alerts |
| `instance_group_filter` | `null` | Regex filter on instance group name |
| `autoscaler_utilization_warning` | `0.80` | Autoscaler capacity utilisation warning (0–1) |
| `autoscaler_utilization_critical` | `0.90` | Autoscaler capacity utilisation critical (0–1) |
| `unhealthy_ratio_warning` | `0.10` | Unhealthy instance ratio warning (0–1) |
| `unhealthy_ratio_critical` | `0.25` | Unhealthy instance ratio critical (0–1) |
| `duration_warning_secs` | `300` | Seconds before warning fires |
| `duration_critical_secs` | `120` | Seconds before critical fires |

### `cloud_storage`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Cloud Storage alerts |
| `bucket_name_filter` | `null` | Regex filter on bucket name |
| `error_count_warning` | `50` | API errors/min — warning |
| `error_count_critical` | `200` | API errors/min — critical |
| `total_bytes_warning` | `null` | Storage size warning (bytes). `null` = disabled |
| `total_bytes_critical` | `null` | Storage size critical (bytes). `null` = disabled |
| `replication_lag_warning_secs` | `60` | Dual-region RPO lag warning (seconds) |
| `replication_lag_critical_secs` | `300` | Dual-region RPO lag critical (seconds) |
| `duration_warning_secs` | `300` | Seconds before warning fires |
| `duration_critical_secs` | `120` | Seconds before critical fires |

### `gemini`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Gemini Enterprise alerts |
| `error_rate_warning_threshold` | `0.05` | API error rate warning (0–1) |
| `error_rate_critical_threshold` | `0.15` | API error rate critical (0–1) |
| `quota_warning_threshold` | `0.80` | Quota consumption warning (0–1) |
| `quota_critical_threshold` | `0.90` | Quota consumption critical (0–1) |
| `duration_warning_secs` | `300` | Seconds before warning fires |
| `duration_critical_secs` | `120` | Seconds before critical fires |

### `ncc`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable NCC alerts |
| `hub_name_filter` | `null` | Regex filter on hub ID |
| `throughput_warning_threshold` | `0.80` | Hub throughput warning (0–1) |
| `throughput_critical_threshold` | `0.90` | Hub throughput critical (0–1) |
| `duration_warning_secs` | `300` | Seconds before warning fires |
| `duration_critical_secs` | `120` | Seconds before critical fires |

### `secret_manager`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Secret Manager alerts |
| `access_denied_warning` | `3` | Access denied events/hour — warning |
| `access_denied_critical` | `10` | Access denied events/hour — critical |
| `duration_warning_secs` | `3600` | Seconds before warning fires |
| `duration_critical_secs` | `3600` | Seconds before critical fires |

### `certificate_manager`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Certificate Manager alerts |
| `expiry_warning_days` | `30` | Certificate expiry warning (days remaining) |
| `expiry_critical_days` | `7` | Certificate expiry critical (days remaining) |
| `duration_warning_secs` | `300` | Seconds before warning fires |
| `duration_critical_secs` | `120` | Seconds before critical fires |

### `project_quotas`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable GCP project quota alerts |
| `allocation_warning_threshold` | `0.80` | Allocation quota usage warning (0–1) |
| `allocation_critical_threshold` | `0.90` | Allocation quota usage critical (0–1) |
| `rate_warning_threshold` | `0.80` | Rate quota usage warning (0–1) |
| `rate_critical_threshold` | `0.90` | Rate quota usage critical (0–1) |
| `duration_warning_secs` | `300` | Seconds before warning fires |
| `duration_critical_secs` | `120` | Seconds before critical fires |

---

## Outputs

| Output | Type | Description |
|---|---|---|
| `pubsub_notification_channel_name` | `string` | Resource name of the Pub/Sub channel. `null` if no topic provided. |
| `email_notification_channel_names` | `map(string)` | Map of email address → channel resource name. |
| `enabled_services` | `list(string)` | Names of all services with active alert policies. |
| `alert_policy_ids` | `map(string)` | Map of alert identifier → GCP alert policy resource name. |

---

## Examples

| Example | Services | Description |
|---|---|---|
| [`examples/minimal`](examples/minimal/main.tf) | GKE, VPC | Quickstart with all defaults |
| [`examples/gke-team`](examples/gke-team/main.tf) | GKE, VPC, Compute, MIG, LB, Pub/Sub, Quotas | Platform team with custom thresholds |
| [`examples/full`](examples/full/main.tf) | All 19 services | Production-grade config with representative overrides |

---

> **Maintained by the Platform / SRE Team.** For questions raise a ticket in Moogsoft.
