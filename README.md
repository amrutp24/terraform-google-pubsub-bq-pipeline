# terraform-google-pubsub-bq-pipeline

A Terraform module that provisions a fully serverless, event-driven pipeline on Google Cloud Platform:

```
Pub/Sub Topic → Push Subscription → Cloud Run → BigQuery
```

Messages published to the Pub/Sub topic are delivered via HTTPS push to a Cloud Run service, which decodes the payload and streams it into a BigQuery table. Authentication between Pub/Sub and Cloud Run uses OIDC tokens — no public endpoints, no API keys.

---

## Architecture

```
┌─────────────────┐     push + OIDC      ┌──────────────────┐     streaming insert     ┌─────────────────┐
│   Pub/Sub Topic │ ──────────────────▶  │  Cloud Run (app) │ ──────────────────────▶  │    BigQuery     │
└─────────────────┘                       └──────────────────┘                           └─────────────────┘
        │                                         │
        │                               env: BQ_PROJECT
        ▼                                    BQ_DATASET
  Push Subscription                           BQ_TABLE
  (OIDC token auth)
```

**Resources created by this module:**
- `google_pubsub_topic` — receives incoming events
- `google_pubsub_subscription` — push subscription wired to Cloud Run
- `google_artifact_registry_repository` — stores the Cloud Run Docker image
- `google_cloud_run_v2_service` — runs the ingestion app
- `google_bigquery_dataset` + `google_bigquery_table` — stores the events
- `google_service_account` × 2 — least-privilege SAs for Cloud Run and Pub/Sub invoker
- IAM bindings — `bigquery.dataEditor`, `bigquery.jobUser`, `run.invoker`

---

## Usage

```hcl
module "pipeline" {
  source  = "amrutp24/pubsub-bq-pipeline/google"
  version = "~> 1.0"

  project    = "my-gcp-project"
  region     = "us-central1"
  topic_name = "my-topic"

  bq_dataset_id = "my_events"
  bq_table_id   = "events"

  image        = "us-central1-docker.pkg.dev/my-project/pubsub-to-bq/app:latest"
  service_name = "pubsub-to-bq"

  labels = {
    environment = "dev"
    team        = "data"
  }
}
```

### Publishing a message

```bash
gcloud pubsub topics publish my-topic \
  --message='{"event":"user_signup","user_id":"123"}' \
  --project=my-gcp-project
```

The row will appear in BigQuery within seconds.

---

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.0 |
| google provider | >= 4.0, < 6.0 |

### Before applying

Enable the required GCP APIs:

```bash
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  bigquery.googleapis.com \
  pubsub.googleapis.com \
  --project=YOUR_PROJECT
```

Build and push the Cloud Run image to Artifact Registry before running `terraform apply`. See the [app source](https://github.com/amrutp24/gcp-pubsub-to-bq/tree/master/app) for the Dockerfile.

---

## Inputs

<!-- BEGIN_TF_DOCS -->
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `project` | GCP project ID | `string` | — | yes |
| `region` | GCP region | `string` | — | yes |
| `topic_name` | Pub/Sub topic name | `string` | — | yes |
| `bq_dataset_id` | BigQuery dataset ID | `string` | — | yes |
| `image` | Docker image URI for Cloud Run | `string` | — | yes |
| `bq_table_id` | BigQuery table ID | `string` | `"events"` | no |
| `bq_dataset_location` | BigQuery dataset location | `string` | `"US"` | no |
| `service_name` | Cloud Run service name | `string` | `"pubsub-to-bq"` | no |
| `cloud_run_max_instances` | Max Cloud Run instances | `number` | `5` | no |
| `cloudrun_sa_account_id` | Cloud Run service account ID | `string` | `null` | no |
| `pubsub_invoker_sa_account_id` | Pub/Sub invoker service account ID | `string` | `null` | no |
| `labels` | Labels to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `cloud_run_url` | URL of the Cloud Run service |
| `topic_id` | Pub/Sub topic ID |
| `subscription_id` | Pub/Sub subscription ID |
| `bq_dataset_id` | BigQuery dataset ID |
| `bq_table_id` | BigQuery table ID |
| `dead_letter_topic_id` | Dead-letter topic ID |
<!-- END_TF_DOCS -->

---

## BigQuery Schema

The default table schema is:

| Column | Type | Description |
|--------|------|-------------|
| `message_id` | STRING | Pub/Sub message ID |
| `publish_time` | TIMESTAMP | Pub/Sub publish timestamp |
| `data` | STRING | Raw decoded message payload |
| `attributes` | STRING | Pub/Sub message attributes (JSON) |

---

## License

MIT
