# GCP Infrastructure Monitoring Alerts — Terraform Module

A reusable Terraform module that provisions **GCP Cloud Monitoring alert policies** for 19 GCP services. Teams enable only the services they use; every alert ships with sensible defaults so minimal configuration is required to get started.

---

## Table of Contents

- [Architecture](#architecture)
- [Supported Services](#supported-services)
- [Prerequisites](#prerequisites)
- [Calling the Module from Git](#calling-the-module-from-git)
- [Quick Start](#quick-start)
- [Module Usage](#module-usage)
- [Notification Channels — Pub/Sub and Email](#notification-channels--pubsub-and-email)
- [Input Variables](#input-variables)
- [Service Variables Reference](#service-variables-reference)
- [Outputs](#outputs)
- [Alert Catalogue](#alert-catalogue)
- [Alerting Best Practices](#alerting-best-practices)
- [Examples](#examples)
- [Contributing](#contributing)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Calling Team (Terraform)                   │
│                                                             │
│   module "monitoring" {                                     │
│     source = "git::https://github.com/ORG/REPO.git         │
│              //modules/gcp-monitoring-alerts?ref=v1.0.0"   │
│     project_id = "my-project"                               │
│     pubsub_notification_topic = "projects/.../topics/..."  │
│     gke        = { enabled = true }                        │
│     cloud_sql  = { enabled = true, cpu_warning = 0.70 }    │
│   }                                                         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              gcp-monitoring-alerts Module                    │
│                                                             │
│  ┌──────────────────────────────────────┐                  │
│  │  google_monitoring_notification_      │                  │
│  │  channel  (type: pubsub)             │                  │
│  └─────────────────────┬────────────────┘                  │
│                         │                                   │
│  ┌──────────────────────▼────────────────┐                 │
│  │  google_monitoring_alert_policy        │                 │
│  │  (one per metric per severity)         │                 │
│  │                                        │                 │
│  │  [GKE][WARNING]  Node CPU High         │                 │
│  │  [GKE][CRITICAL] Node CPU Critical     │                 │
│  │  [CloudRun][WARNING]  Error Rate High  │                 │
│  │  ... (60+ policies across 19 services) │                 │
│  └────────────────────────────────────────┘                 │
│                                                             │
│  ┌─────────────────────────────────────────┐               │
│  │  google_logging_metric                   │               │
│  │  (log-based metrics for events without   │               │
│  │   native Cloud Monitoring metrics)       │               │
│  └─────────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────────────┐
        │   Cloud Monitoring Notification Channels    │
        │                                            │
        │  ┌─────────────────┐  ┌─────────────────┐ │
        │  │  Pub/Sub Topic  │  │  Email Channel  │ │
        │  │  (optional)     │  │  (optional)     │ │
        │  └────────┬────────┘  └────────┬────────┘ │
        └───────────┼────────────────────┼───────────┘
                    │ push subscription   │ direct email
                    ▼                    ▼
        ┌───────────────────┐   ┌────────────────────┐
        │  Cloud Run        │   │  On-call            │
        │  Function         │   │  distribution list  │
        │  (alert-processor)│   │  (team inboxes)     │
        └────────┬──────────┘   └────────────────────┘
                 │
                 ▼
        Moogsoft (on-prem)
        (ticketing & event correlation)
```

**Alert flow:**
1. GCP Cloud Monitoring evaluates metric conditions every minute.
2. When a condition is met for the configured duration, the alert fires.
3. All configured notification channels receive the alert simultaneously:
   - **Pub/Sub** → Cloud Run function → Moogsoft (on-prem) for ticketing
   - **Email** → direct delivery to configured distribution list(s)

---

## Supported Services

| # | Service | Alert Count | Metric Types Used |
|---|---------|:-----------:|-------------------|
| 1 | GKE | 8 | Node CPU/memory, container restarts, CPU limits |
| 2 | Cloud Run | 6 | Latency P99, error rate (MQL), memory |
| 3 | Cloud SQL | 10 | CPU, memory, disk, connections, replication lag |
| 4 | VPC / Subnet | 6 | Subnet IP utilisation, firewall drops, NAT failures |
| 5 | BigQuery | 8 | Slot utilisation (MQL), job duration, table count, failed jobs |
| 6 | Compute Engine | 8 | CPU, memory, disk (Ops Agent), disk I/O throttle |
| 7 | Load Balancer | 6 | 5xx rate (MQL), backend latency P95, SSL expiry |
| 8 | Pub/Sub | 8 | Oldest message age, undelivered count, DLQ depth, publish errors |
| 9 | Cloud Armor | 3 | Denied rate, allowed volume spike (MQL) |
| 10 | Vertex AI | 8 | Prediction errors/latency, endpoint CPU, pipeline failures |
| 11 | Apigee | 6 | Error rate (MQL), latency P99, quota violations |
| 12 | Managed Instance Groups | 4 | Autoscaler utilisation, unhealthy instance ratio (MQL) |
| 13 | Cloud Storage | 6 | API errors, storage size (optional), replication lag |
| 14 | Gemini Enterprise | 4 | API error rate (MQL), quota utilisation (MQL) |
| 15 | NCC Spokes | 4 | Spoke state changes (log-based), hub throughput, BGP sessions |
| 16 | Secret Manager | 3 | Access denied (log-based), version destroyed (log-based) |
| 17 | Certificate Manager | 3 | SSL expiry (uptime check), provisioning failures (log-based) |
| 18 | GCP Project Quotas | 4 | Allocation usage (MQL ratio), rate quota (MQL ratio) |

> **Note:** Services marked **(MQL)** use Monitoring Query Language for ratio-based conditions (e.g. error rate = 5xx / total). Services marked **(log-based)** create `google_logging_metric` resources alongside alert policies.

---

## Prerequisites

| Requirement | Details |
|---|---|
| **Terraform** | `>= 1.3.0` — required for `optional()` with default values in object variables |
| **Google Provider** | `>= 5.0, < 7.99` |
| **GCP APIs** | `monitoring.googleapis.com`, `logging.googleapis.com` must be enabled in the target project |
| **IAM** | The Terraform service account needs `roles/monitoring.alertPolicyEditor`, `roles/logging.admin` (for log-based metrics), and `roles/monitoring.notificationChannelEditor` |
| **Pub/Sub topic** | An existing Pub/Sub topic in the target project. The module creates the notification channel; it does **not** create the topic. |
| **Ops Agent** | Compute Engine memory and disk alerts require the [Google Cloud Ops Agent](https://cloud.google.com/stackdriver/docs/solutions/agents/ops-agent) to be installed on instances. |
| **GKE System Metrics** | GKE container and node metrics require GKE System Metrics to be enabled on the cluster. |

### Required IAM Roles

Grant these roles to the Terraform service account in the target project:

```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:tf-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/monitoring.alertPolicyEditor"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:tf-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/monitoring.notificationChannelEditor"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:tf-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/logging.admin"
```

Also grant the Cloud Monitoring service account permission to publish to your Pub/Sub topic:

```bash
# Find the Cloud Monitoring service account
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.role=roles/monitoring.notificationServiceAgent"

# Grant publish permission
gcloud pubsub topics add-iam-policy-binding TOPIC_NAME \
  --member="serviceAccount:service-PROJECT_NUMBER@gcp-sa-monitoring-notification.iam.gserviceaccount.com" \
  --role="roles/pubsub.publisher"
```

---

## Calling the Module from Git

When this repository is hosted on GitHub or Bitbucket, reference the module using a git source URL. The `//` separates the repository root from the module subdirectory, and `?ref=` pins to a specific tag, branch, or commit SHA.

### GitHub

```hcl
module "monitoring" {
  source = "git::https://github.com/YOUR_ORG/YOUR_REPO.git//modules/gcp-monitoring-alerts?ref=v1.0.0"

  project_id                = "my-project-id"
  pubsub_notification_topic = "projects/my-project-id/topics/gcp-monitoring-alerts"

  gke = { enabled = true }
}
```

### Bitbucket

```hcl
module "monitoring" {
  source = "git::https://bitbucket.org/YOUR_ORG/YOUR_REPO.git//modules/gcp-monitoring-alerts?ref=v1.0.0"

  project_id                = "my-project-id"
  pubsub_notification_topic = "projects/my-project-id/topics/gcp-monitoring-alerts"

  gke = { enabled = true }
}
```

> **Tip — pin to a tag, not `main`.** Using `?ref=main` means every `terraform init` may pull a different version. Tag releases (`v1.0.0`, `v1.1.0`, …) give teams stable, reproducible builds. Run `git tag v1.0.0 && git push origin v1.0.0` on the repo after testing.

### SSH authentication (private repos)

For private Bitbucket/GitHub repos accessed via SSH:

```hcl
source = "git::ssh://git@bitbucket.org/YOUR_ORG/YOUR_REPO.git//modules/gcp-monitoring-alerts?ref=v1.0.0"
```

Ensure the host running `terraform init` has the SSH key configured and the key added to the repo's access keys in Bitbucket / deploy keys in GitHub.

### Local development

During local development, use a relative path instead:

```hcl
source = "../../modules/gcp-monitoring-alerts"
```

---

## Quick Start

### 1. Create the Pub/Sub topic

```bash
gcloud pubsub topics create gcp-monitoring-alerts --project=YOUR_PROJECT_ID
```

### 2. Call the module

```hcl
module "monitoring" {
  # Replace with your org/repo and a release tag
  source = "git::https://github.com/YOUR_ORG/YOUR_REPO.git//modules/gcp-monitoring-alerts?ref=v1.0.0"

  project_id                = "my-project-id"
  pubsub_notification_topic = "projects/my-project-id/topics/gcp-monitoring-alerts"

  default_labels = {
    team = "platform"
    env  = "prod"
  }

  # Enable only the services your team uses — everything else defaults to disabled.
  gke       = { enabled = true }
  cloud_sql = { enabled = true }
  pubsub    = { enabled = true }
}
```

### 3. Apply

```bash
terraform init
terraform plan
terraform apply
```

### 4. Wire up Cloud Run as the alert processor

Create a Pub/Sub **push subscription** pointing to your Cloud Run function URL:

```bash
# Create a push subscription that delivers to Cloud Run
gcloud pubsub subscriptions create monitoring-alerts-push \
  --topic=gcp-monitoring-alerts \
  --push-endpoint=https://YOUR_CLOUD_RUN_URL/alerts \
  --push-auth-service-account=YOUR_SA@YOUR_PROJECT.iam.gserviceaccount.com \
  --project=YOUR_PROJECT_ID
```

The Cloud Run function receives POST requests from Pub/Sub. The message body is base64-encoded JSON — see the [Alert payload format](#alert-payload-format) section for the schema.

For local testing without Cloud Run, create a pull subscription instead:

```bash
gcloud pubsub subscriptions create monitoring-test-sub \
  --topic=gcp-monitoring-alerts \
  --project=YOUR_PROJECT_ID

gcloud pubsub subscriptions pull monitoring-test-sub --auto-ack
```

---

## Module Usage

### Enable a service (zero config required)

All threshold variables have defaults so passing `{ enabled = true }` is sufficient:

```hcl
module "monitoring" {
  source    = "git::https://github.com/YOUR_ORG/YOUR_REPO.git//modules/gcp-monitoring-alerts?ref=v1.0.0"
  project_id = "my-project"
  pubsub_notification_topic = "projects/my-project/topics/alerts"

  gke = { enabled = true }
}
```

### Customise thresholds

Override only the values that differ from your needs:

```hcl
module "monitoring" {
  source    = "git::https://github.com/YOUR_ORG/YOUR_REPO.git//modules/gcp-monitoring-alerts?ref=v1.0.0"
  project_id = "my-project"
  pubsub_notification_topic = "projects/my-project/topics/alerts"

  gke = {
    enabled                      = true
    cluster_name                 = "prod-cluster"     # scope to a specific cluster
    node_cpu_warning_threshold   = 0.70               # override default (0.75)
    node_cpu_critical_threshold  = 0.85
    container_restart_warning    = 2                  # stricter than default (3)
    duration_critical_secs       = 60                 # faster critical firing
  }

  cloud_sql = {
    enabled                       = true
    database_id_filter            = ".*:prod-db.*"    # regex filter on database_id
    replication_lag_warning_secs  = 20
    replication_lag_critical_secs = 60
  }

  cloud_storage = {
    enabled              = true
    total_bytes_warning  = 1073741824000   # 1 TB — cost control alert
    total_bytes_critical = 5368709120000   # 5 TB
  }
}
```

### Add runbook links to documentation

```hcl
module "monitoring" {
  source    = "git::https://github.com/YOUR_ORG/YOUR_REPO.git//modules/gcp-monitoring-alerts?ref=v1.0.0"
  project_id = "my-project"
  pubsub_notification_topic = "projects/my-project/topics/alerts"

  alert_documentation_prefix = "https://wiki.example.com"
  # Alert documentation will include: https://wiki.example.com/runbooks/gke-cpu
}
```

### Deploy without a notification channel (console-only)

Omit `pubsub_notification_topic` to create alert policies that are visible in the Cloud Monitoring console but do not send notifications:

```hcl
module "monitoring" {
  source    = "git::https://github.com/YOUR_ORG/YOUR_REPO.git//modules/gcp-monitoring-alerts?ref=v1.0.0"
  project_id = "my-project"
  # pubsub_notification_topic not set

  gke = { enabled = true }
}
```

---

## Notification Channels — Pub/Sub and Email

The module supports two notification channel types that can be used independently or together. When both are configured, every alert is delivered to all channels simultaneously.

| Channel | Variable | When to use |
|---|---|---|
| **Pub/Sub** | `pubsub_notification_topic` | Forward to Cloud Run → Moogsoft for automated ticketing |
| **Email** | `email_notification_addresses` | Direct delivery to on-call distribution lists |

### Pub/Sub only

```hcl
module "monitoring" {
  source    = "git::https://github.com/YOUR_ORG/YOUR_REPO.git//modules/gcp-monitoring-alerts?ref=v1.0.0"
  project_id = "my-project"

  pubsub_notification_topic = "projects/my-project/topics/gcp-monitoring-alerts"

  gke = { enabled = true }
}
```

### Email only

```hcl
module "monitoring" {
  source    = "git::https://github.com/YOUR_ORG/YOUR_REPO.git//modules/gcp-monitoring-alerts?ref=v1.0.0"
  project_id = "my-project"

  email_notification_addresses = [
    "platform-alerts@example.com",
    "sre-oncall@example.com",
  ]

  gke = { enabled = true }
}
```

### Both channels (recommended for production)

```hcl
module "monitoring" {
  source    = "git::https://github.com/YOUR_ORG/YOUR_REPO.git//modules/gcp-monitoring-alerts?ref=v1.0.0"
  project_id = "my-project"

  pubsub_notification_topic = "projects/my-project/topics/gcp-monitoring-alerts"

  email_notification_addresses = [
    "platform-alerts@example.com",
    "sre-oncall@example.com",
  ]

  gke = { enabled = true }
}
```

### Pub/Sub topic format

```
pubsub_notification_topic = "projects/{project_id}/topics/{topic_name}"
```

When an alert fires, Cloud Monitoring publishes to the topic. A Cloud Run function with a Pub/Sub **push subscription** receives each message, decodes it, and forwards the event to Moogsoft (on-prem) based on the `severity` and `service` labels in the payload.

### Alert payload format

Pub/Sub wraps the Cloud Monitoring incident JSON as a base64-encoded message. Your Cloud Run function receives a POST body like this:

```json
{
  "message": {
    "data": "<base64-encoded incident JSON>",
    "messageId": "...",
    "publishTime": "2024-01-01T00:00:00Z",
    "attributes": {}
  },
  "subscription": "projects/my-project/subscriptions/monitoring-alerts-push"
}
```

After base64-decoding `message.data`, the incident JSON is:

```json
{
  "incident": {
    "incident_id": "0.opqiyfxx36wg",
    "resource_id": "...",
    "resource_name": "...",
    "resource": {
      "type": "gce_instance",
      "labels": { "instance_id": "1234567890", "zone": "asia-southeast1-a" }
    },
    "metric": {
      "type": "compute.googleapis.com/instance/cpu/utilization",
      "displayName": "CPU utilization",
      "labels": {}
    },
    "state": "open",
    "started_at": 1700000000,
    "ended_at": null,
    "policy_name": "projects/my-project/alertPolicies/12345",
    "policy_user_labels": {
      "severity": "warning",
      "service": "compute-instance",
      "managed_by": "terraform",
      "team": "platform",
      "env": "prod"
    },
    "condition_name": "Instance CPU utilisation > 75%",
    "url": "https://console.cloud.google.com/monitoring/alerting/incidents/..."
  },
  "version": "1.2"
}
```

### Cloud Run function — example handler (Python)

```python
import base64
import json
import functions_framework

@functions_framework.http
def alert_processor(request):
    envelope = request.get_json(silent=True)
    if not envelope or "message" not in envelope:
        return "Bad Request: missing Pub/Sub message", 400

    # Decode the base64 Pub/Sub message body
    data = base64.b64decode(envelope["message"]["data"]).decode("utf-8")
    incident = json.loads(data).get("incident", {})

    severity = incident.get("policy_user_labels", {}).get("severity", "unknown")
    service  = incident.get("policy_user_labels", {}).get("service", "unknown")
    state    = incident.get("state", "unknown")        # "open" or "closed"
    url      = incident.get("url", "")

    if state == "open":
        forward_to_moogsoft(incident)   # on-prem Moogsoft REST API
    elif state == "closed":
        resolve_in_moogsoft(incident)   # auto-resolve the Moogsoft event

    # Return 2xx so Pub/Sub does not redeliver
    return "OK", 200
```

### Routing logic

Use the labels in `incident.policy_user_labels` to route:

| Label | Values | Routing example |
|---|---|---|
| `severity` | `warning`, `critical` | Set Moogsoft event severity (critical = P1/P2, warning = P3/P4) |
| `service` | `gke`, `cloud-run`, `cloud-sql`, etc. | Route to the owning team's channel |
| `team` | Caller-defined via `default_labels` | Route to the correct team queue |
| `env` | Caller-defined via `default_labels` | Suppress non-prod warnings outside business hours |
| `state` | `open`, `closed` | Send resolution notifications when `state = "closed"` |

### Push subscription IAM

The Cloud Run service URL must be protected. Grant the Pub/Sub service account permission to invoke Cloud Run:

```bash
gcloud run services add-iam-policy-binding alert-processor \
  --region=YOUR_REGION \
  --member="serviceAccount:service-PROJECT_NUMBER@gcp-sa-pubsub.iam.gserviceaccount.com" \
  --role="roles/run.invoker"
```

---

## Input Variables

### Module-level variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `project_id` | `string` | **required** | GCP project ID where alert policies are created |
| `pubsub_notification_topic` | `string` | `null` | Full Pub/Sub topic resource name. Format: `projects/{project}/topics/{topic}`. Leave `null` to skip Pub/Sub. |
| `pubsub_notification_channel_display_name` | `string` | `"GCP Monitoring Alerts - Pub/Sub"` | Display name for the Pub/Sub notification channel |
| `email_notification_addresses` | `list(string)` | `[]` | Email addresses to notify. One channel is created per address. Can be used with or without Pub/Sub. |
| `default_labels` | `map(string)` | `{}` | Labels applied to every alert policy (e.g. `{ team = "platform", env = "prod" }`) |
| `alert_documentation_prefix` | `string` | `""` | URL prefix prepended to runbook links in alert documentation |

---

## Service Variables Reference

Each service accepts an object variable with `optional()` fields. Pass `{ enabled = true }` for defaults, or override individual fields.

### `gke`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable GKE alerts |
| `cluster_name` | `null` | Filter to a specific cluster name (null = all clusters) |
| `location` | `null` | Filter to a specific location / region (null = all) |
| `labels` | `{}` | Extra labels on GKE alert policies |
| `node_cpu_warning_threshold` | `0.75` | Node CPU warning threshold (0–1) |
| `node_cpu_critical_threshold` | `0.90` | Node CPU critical threshold (0–1) |
| `node_memory_warning_threshold` | `0.80` | Node memory warning threshold (0–1) |
| `node_memory_critical_threshold` | `0.90` | Node memory critical threshold (0–1) |
| `container_restart_warning` | `3` | Container restarts/5 min — warning |
| `container_restart_critical` | `10` | Container restarts/5 min — critical |
| `container_cpu_warning_threshold` | `0.80` | Container CPU limit utilisation warning (0–1) |
| `container_cpu_critical_threshold` | `0.95` | Container CPU limit utilisation critical (0–1) |
| `duration_warning_secs` | `300` | Seconds condition must be true before warning fires |
| `duration_critical_secs` | `120` | Seconds condition must be true before critical fires |

### `cloud_run`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Cloud Run alerts |
| `service_name` | `null` | Filter to a specific Cloud Run service (null = all) |
| `location` | `null` | Filter to a specific region |
| `latency_p99_warning_ms` | `2000` | P99 latency warning threshold (ms) |
| `latency_p99_critical_ms` | `5000` | P99 latency critical threshold (ms) |
| `error_rate_warning_threshold` | `0.01` | 5xx error rate warning (0–1, e.g. 0.01 = 1%) |
| `error_rate_critical_threshold` | `0.05` | 5xx error rate critical (0–1) |
| `memory_warning_threshold` | `0.80` | Container memory utilisation warning (0–1) |
| `memory_critical_threshold` | `0.95` | Container memory utilisation critical (0–1) |

### `cloud_sql`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Cloud SQL alerts |
| `database_id_filter` | `null` | Regex filter on `database_id` label (null = all instances) |
| `cpu_warning_threshold` | `0.75` | CPU utilisation warning (0–1) |
| `cpu_critical_threshold` | `0.90` | CPU utilisation critical (0–1) |
| `memory_warning_threshold` | `0.80` | Memory utilisation warning (0–1) |
| `memory_critical_threshold` | `0.90` | Memory utilisation critical (0–1) |
| `disk_warning_threshold` | `0.75` | Disk utilisation warning (0–1) |
| `disk_critical_threshold` | `0.85` | Disk utilisation critical (0–1) |
| `connections_warning_threshold` | `0.80` | Connection count warning ratio (0–1) |
| `connections_critical_threshold` | `0.90` | Connection count critical ratio (0–1) |
| `replication_lag_warning_secs` | `30` | Read replica lag warning (seconds) |
| `replication_lag_critical_secs` | `120` | Read replica lag critical (seconds) |

### `vpc`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable VPC / Subnet alerts |
| `subnetwork_name` | `null` | Filter to a specific subnetwork name |
| `subnet_ip_warning_threshold` | `0.70` | Subnet IP utilisation warning (0–1) |
| `subnet_ip_critical_threshold` | `0.85` | Subnet IP utilisation critical (0–1) |
| `firewall_drop_warning` | `100` | Firewall dropped packets/min — warning |
| `firewall_drop_critical` | `500` | Firewall dropped packets/min — critical |
| `nat_alloc_fail_warning` | `1` | NAT port allocation failures — warning |
| `nat_alloc_fail_critical` | `10` | NAT port allocation failures — critical |

### `bigquery`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable BigQuery alerts |
| `slot_utilization_warning` | `0.80` | Slot utilisation warning (0–1) |
| `slot_utilization_critical` | `0.95` | Slot utilisation critical (0–1) |
| `job_execution_warning_secs` | `600` | P99 job execution time warning (seconds) |
| `job_execution_critical_secs` | `1800` | P99 job execution time critical (seconds) |
| `table_count_warning` | `8000` | Tables per dataset warning (hard limit: 10,000) |
| `table_count_critical` | `9500` | Tables per dataset critical |
| `failed_jobs_warning` | `5` | Failed jobs per hour — warning |
| `failed_jobs_critical` | `20` | Failed jobs per hour — critical |

### `compute_instance`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Compute Engine instance alerts |
| `instance_name_filter` | `null` | Regex filter on `instance_name` label |
| `cpu_warning_threshold` | `0.75` | CPU utilisation warning (0–1) |
| `cpu_critical_threshold` | `0.90` | CPU utilisation critical (0–1) |
| `memory_warning_threshold` | `0.80` | Memory utilisation warning (0–1) — requires Ops Agent |
| `memory_critical_threshold` | `0.90` | Memory utilisation critical (0–1) — requires Ops Agent |
| `disk_warning_threshold` | `0.80` | Disk utilisation warning (0–1) — requires Ops Agent |
| `disk_critical_threshold` | `0.90` | Disk utilisation critical (0–1) — requires Ops Agent |
| `disk_io_warning` | `100` | Throttled disk ops/min — warning |
| `disk_io_critical` | `500` | Throttled disk ops/min — critical |

### `load_balancer`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable HTTP(S) Load Balancer alerts |
| `forwarding_rule_filter` | `null` | Regex filter on forwarding rule name |
| `error_rate_warning_threshold` | `0.01` | 5xx error rate warning (0–1) |
| `error_rate_critical_threshold` | `0.05` | 5xx error rate critical (0–1) |
| `latency_p95_warning_ms` | `1000` | Backend P95 latency warning (ms) |
| `latency_p95_critical_ms` | `3000` | Backend P95 latency critical (ms) |
| `ssl_expiry_warning_days` | `30` | SSL certificate expiry warning (days remaining) |
| `ssl_expiry_critical_days` | `7` | SSL certificate expiry critical (days remaining) |

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
| `publish_error_warning` | `10` | Topic publish errors/min — warning |
| `publish_error_critical` | `50` | Topic publish errors/min — critical |

### `cloud_armor`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Cloud Armor alerts |
| `security_policy_filter` | `null` | Regex filter on security policy name |
| `denied_requests_warning` | `100` | Denied requests/min — warning |
| `denied_requests_critical` | `1000` | Denied requests/min — critical |

### `vertex_ai`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Vertex AI alerts |
| `endpoint_filter` | `null` | Regex filter on endpoint ID |
| `error_count_warning` | `10` | Prediction errors/min — warning |
| `error_count_critical` | `50` | Prediction errors/min — critical |
| `latency_p99_warning_ms` | `2000` | Prediction P99 latency warning (ms) |
| `latency_p99_critical_ms` | `5000` | Prediction P99 latency critical (ms) |
| `cpu_warning_threshold` | `0.75` | Endpoint CPU utilisation warning (0–1) |
| `cpu_critical_threshold` | `0.90` | Endpoint CPU utilisation critical (0–1) |
| `pipeline_fail_warning` | `1` | Pipeline task failures — warning |
| `pipeline_fail_critical` | `5` | Pipeline task failures — critical |

### `apigee`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Apigee alerts |
| `proxy_name_filter` | `null` | Regex filter on proxy name |
| `error_rate_warning_threshold` | `0.01` | 5xx error rate warning (0–1) |
| `error_rate_critical_threshold` | `0.05` | 5xx error rate critical (0–1) |
| `latency_p99_warning_ms` | `2000` | Proxy P99 response latency warning (ms) |
| `latency_p99_critical_ms` | `5000` | Proxy P99 response latency critical (ms) |
| `quota_violation_warning` | `100` | Quota violations/hour — warning |
| `quota_violation_critical` | `500` | Quota violations/hour — critical |

### `mig`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Managed Instance Group alerts |
| `instance_group_filter` | `null` | Regex filter on instance group name |
| `autoscaler_utilization_warning` | `0.80` | Autoscaler capacity utilisation warning (0–1) |
| `autoscaler_utilization_critical` | `0.95` | Autoscaler capacity utilisation critical (0–1) |
| `unhealthy_ratio_warning` | `0.10` | Unhealthy instance ratio warning (0–1) |
| `unhealthy_ratio_critical` | `0.25` | Unhealthy instance ratio critical (0–1) |

### `cloud_storage`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Cloud Storage alerts |
| `bucket_name_filter` | `null` | Regex filter on bucket name |
| `error_count_warning` | `50` | API errors/min — warning |
| `error_count_critical` | `200` | API errors/min — critical |
| `total_bytes_warning` | `null` | Storage size warning threshold (bytes). `null` = disabled |
| `total_bytes_critical` | `null` | Storage size critical threshold (bytes). `null` = disabled |
| `replication_lag_warning_secs` | `60` | Dual-region RPO lag warning (seconds) |
| `replication_lag_critical_secs` | `300` | Dual-region RPO lag critical (seconds) |

### `gemini`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Gemini Enterprise alerts |
| `error_rate_warning_threshold` | `0.05` | API error rate warning (0–1) |
| `error_rate_critical_threshold` | `0.15` | API error rate critical (0–1) |
| `quota_warning_threshold` | `0.80` | Quota consumption warning (0–1) |
| `quota_critical_threshold` | `0.95` | Quota consumption critical (0–1) |

### `ncc`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable NCC alerts |
| `hub_name_filter` | `null` | Regex filter on hub ID |
| `throughput_warning_threshold` | `0.70` | Hub data plane throughput warning (0–1) |
| `throughput_critical_threshold` | `0.85` | Hub data plane throughput critical (0–1) |

### `secret_manager`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Secret Manager alerts |
| `access_denied_warning` | `3` | Access denied events/hour — warning |
| `access_denied_critical` | `10` | Access denied events/hour — critical |

### `certificate_manager`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable Certificate Manager alerts |
| `expiry_warning_days` | `30` | Certificate expiry warning (days remaining) |
| `expiry_critical_days` | `7` | Certificate expiry critical (days remaining) |

### `project_quotas`

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enable GCP project quota alerts |
| `allocation_warning_threshold` | `0.75` | Allocation quota usage warning (0–1) |
| `allocation_critical_threshold` | `0.90` | Allocation quota usage critical (0–1) |
| `rate_warning_threshold` | `0.80` | Rate quota usage warning (0–1) |
| `rate_critical_threshold` | `0.95` | Rate quota usage critical (0–1) |

---

## Outputs

| Output | Type | Description |
|---|---|---|
| `pubsub_notification_channel_name` | `string` | Resource name of the Pub/Sub notification channel. `null` if no topic was provided. |
| `email_notification_channel_names` | `map(string)` | Map of email address → notification channel resource name. Empty map if no addresses provided. |
| `enabled_services` | `list(string)` | List of service names for which alert policies are enabled. |
| `alert_policy_ids` | `map(string)` | Map of alert identifier → GCP alert policy resource name. Only enabled services are included. |

### Example output usage

```hcl
output "monitoring_channel" {
  value = module.monitoring.pubsub_notification_channel_name
}
# → "projects/my-project/notificationChannels/1234567890"

output "gke_cpu_policy_id" {
  value = module.monitoring.alert_policy_ids["gke_node_cpu_critical"]
}
# → "projects/my-project/alertPolicies/987654321"
```

---

## Alert Catalogue

### Severity levels

| Severity | `user_label.severity` | Typical duration | Action |
|---|---|---|---|
| **Warning** | `warning` | 5 minutes | Investigate and monitor |
| **Critical** | `critical` | 1–2 minutes | Immediate response required |

### Alert naming convention

```
[SERVICE][SEVERITY] Description
```

Examples:
- `[GKE][WARNING] Node CPU Utilisation High`
- `[CloudSQL][CRITICAL] Disk Utilisation Critical`
- `[PubSub][WARNING] Subscription Message Backlog Growing`

### GKE alerts

| Alert | Severity | Default Threshold | Metric |
|---|---|---|---|
| Node CPU Utilisation High | WARNING | > 75% | `kubernetes.io/node/cpu/allocatable_utilization` |
| Node CPU Utilisation Critical | CRITICAL | > 90% | `kubernetes.io/node/cpu/allocatable_utilization` |
| Node Memory Utilisation High | WARNING | > 80% | `kubernetes.io/node/memory/allocatable_utilization` |
| Node Memory Utilisation Critical | CRITICAL | > 90% | `kubernetes.io/node/memory/allocatable_utilization` |
| Container Restart Rate High | WARNING | > 3 / 5 min | `kubernetes.io/container/restart_count` |
| Container Crash Loop Detected | CRITICAL | > 10 / 5 min | `kubernetes.io/container/restart_count` |
| Container CPU Limit High | WARNING | > 80% of limit | `kubernetes.io/container/cpu/limit_utilization` |
| Container CPU Limit Saturation | CRITICAL | > 95% of limit | `kubernetes.io/container/cpu/limit_utilization` |

### Cloud Run alerts

| Alert | Severity | Default Threshold | Metric |
|---|---|---|---|
| Request Latency P99 High | WARNING | > 2000ms | `run.googleapis.com/request_latencies` |
| Request Latency P99 Critical | CRITICAL | > 5000ms | `run.googleapis.com/request_latencies` |
| 5xx Error Rate High | WARNING | > 1% | `run.googleapis.com/request_count` (MQL ratio) |
| 5xx Error Rate Critical | CRITICAL | > 5% | `run.googleapis.com/request_count` (MQL ratio) |
| Container Memory High | WARNING | > 80% | `run.googleapis.com/container/memory/utilizations` |
| Container Memory Near Limit | CRITICAL | > 95% | `run.googleapis.com/container/memory/utilizations` |

### Cloud SQL alerts

| Alert | Severity | Default Threshold |
|---|---|---|
| CPU High | WARNING | > 75% |
| CPU Critical | CRITICAL | > 90% |
| Memory High | WARNING | > 80% |
| Memory Critical | CRITICAL | > 90% |
| Disk High | WARNING | > 75% |
| Disk Critical | CRITICAL | > 85% |
| Connection Count High | WARNING | > 80% of max |
| Connection Count Critical | CRITICAL | > 90% of max |
| Replication Lag High | WARNING | > 30s |
| Replication Lag Critical | CRITICAL | > 120s |

> Full alert catalogues for all 19 services are available in the source files under `modules/gcp-monitoring-alerts/alerts/`.

---

## Alerting Best Practices

This module follows these principles:

1. **Alert on symptoms, not causes** — CPU alerts fire when performance degrades, not when a deployment happens.
2. **Separate warning and critical** — Warning gives time to investigate; critical demands immediate action. Different `duration` values prevent noise: warnings sustain for 5 minutes, criticals for 1–2 minutes.
3. **One policy per metric per severity** — Allows independent silencing, snooze, and notification routing without affecting other alerts.
4. **MQL for ratio-based conditions** — Error rates (5xx/total) use Monitoring Query Language because `condition_threshold` cannot compute ratios natively.
5. **Log-based metrics for event-driven signals** — Secret Manager access denied, BigQuery job failures, NCC spoke state changes, and Certificate Manager provisioning failures do not have native Cloud Monitoring metrics and use `google_logging_metric` instead.
6. **Severity labels** — Every policy carries `severity = "warning"|"critical"` in `user_labels`. Use these labels to filter the Cloud Monitoring console and route Pub/Sub messages to the correct handler.
7. **Auto-close** — All policies auto-close after 7 days (`auto_close = "604800s"`) to prevent stale open incidents.
8. **Documentation with runbook links** — Every alert policy includes a `documentation` block with a description and a runbook URL (using `alert_documentation_prefix`).

---

## Examples

| Example | Description | Services Enabled |
|---|---|---|
| [`examples/minimal`](examples/minimal/main.tf) | Quickstart — zero config beyond enabling | GKE, VPC |
| [`examples/gke-team`](examples/gke-team/main.tf) | Platform team with custom thresholds | GKE, VPC, Compute, MIG, LB, Pub/Sub, Quotas |
| [`examples/full`](examples/full/main.tf) | All 19 services, production-grade config | All services |

---

## Repository Structure

```
.
├── modules/
│   └── gcp-monitoring-alerts/        # The reusable module
│       ├── versions.tf               # Terraform + provider constraints
│       ├── variables.tf              # All input variables
│       ├── locals.tf                 # Shared labels, notification channel local
│       ├── main.tf                   # Pub/Sub notification channel resource
│       ├── outputs.tf                # alert_policy_ids, enabled_services
│       └── alerts/                   # One .tf file per service
│           ├── gke.tf
│           ├── cloud_run.tf
│           ├── cloud_sql.tf
│           ├── vpc.tf
│           ├── bigquery.tf
│           ├── compute_instance.tf
│           ├── load_balancer.tf
│           ├── pubsub.tf
│           ├── cloud_armor.tf
│           ├── vertex_ai.tf
│           ├── apigee.tf
│           ├── mig.tf
│           ├── cloud_storage.tf
│           ├── gemini.tf
│           ├── ncc.tf
│           ├── secret_manager.tf
│           ├── certificate_manager.tf
│           └── project_quotas.tf
└── examples/
    ├── minimal/
    ├── gke-team/
    └── full/
```

---

## Contributing

1. Branch from `main`: `git checkout -b feature/add-dataflow-alerts`
2. Add or modify the relevant `alerts/<service>.tf` file.
3. Add the corresponding variable block to `variables.tf`.
4. Add alert policy IDs to `outputs.tf`.
5. Run validation:
   ```bash
   cd modules/gcp-monitoring-alerts
   terraform init -backend=false
   terraform fmt -check -recursive
   terraform validate
   ```
6. Update this README if adding a new service.
7. Open a pull request with a description of the new alerts and their metric sources.

---

> **Maintained by the Platform / SRE Team.** For questions, open a Bitbucket issue or raise a ticket in Moogsoft.
