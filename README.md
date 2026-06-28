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
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 4.0, < 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 4.0, < 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_artifact_registry_repository.repo](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository) | resource |
| [google_bigquery_dataset.dataset](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_dataset) | resource |
| [google_bigquery_table.table](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_table) | resource |
| [google_cloud_run_v2_service.service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service) | resource |
| [google_cloud_run_v2_service_iam_member.pubsub_invoker](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service_iam_member) | resource |
| [google_monitoring_alert_policy.dead_letter](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_alert_policy) | resource |
| [google_monitoring_notification_channel.dead_letter_email](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_notification_channel) | resource |
| [google_project_iam_member.cloudrun_bq_data_editor](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cloudrun_bq_job_user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_pubsub_subscription.subscription](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_subscription) | resource |
| [google_pubsub_subscription_iam_member.dead_letter_subscriber](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_subscription_iam_member) | resource |
| [google_pubsub_topic.dead_letter](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic) | resource |
| [google_pubsub_topic.topic](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic) | resource |
| [google_pubsub_topic_iam_member.dead_letter_publisher](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic_iam_member) | resource |
| [google_service_account.cloudrun_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.pubsub_invoker_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_project.project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alert_email"></a> [alert\_email](#input\_alert\_email) | Email address to notify when messages land in the dead-letter topic. Set to null to disable alerting. | `string` | `null` | no |
| <a name="input_bq_dataset_id"></a> [bq\_dataset\_id](#input\_bq\_dataset\_id) | BigQuery dataset ID | `string` | n/a | yes |
| <a name="input_bq_dataset_location"></a> [bq\_dataset\_location](#input\_bq\_dataset\_location) | BigQuery dataset location | `string` | `"US"` | no |
| <a name="input_bq_table_id"></a> [bq\_table\_id](#input\_bq\_table\_id) | BigQuery table ID | `string` | `"events"` | no |
| <a name="input_cloud_run_max_instances"></a> [cloud\_run\_max\_instances](#input\_cloud\_run\_max\_instances) | Maximum number of Cloud Run instances | `number` | `5` | no |
| <a name="input_cloudrun_sa_account_id"></a> [cloudrun\_sa\_account\_id](#input\_cloudrun\_sa\_account\_id) | Account ID for the Cloud Run service account (defaults to <service\_name>-sa) | `string` | `null` | no |
| <a name="input_image"></a> [image](#input\_image) | Docker image URI for the Cloud Run service | `string` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_max_delivery_attempts"></a> [max\_delivery\_attempts](#input\_max\_delivery\_attempts) | Number of delivery attempts before a message is sent to the dead-letter topic | `number` | `5` | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project ID | `string` | n/a | yes |
| <a name="input_pubsub_invoker_sa_account_id"></a> [pubsub\_invoker\_sa\_account\_id](#input\_pubsub\_invoker\_sa\_account\_id) | Account ID for the Pub/Sub invoker service account (defaults to <service\_name>-invoker) | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | GCP region | `string` | n/a | yes |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | Name of the Cloud Run service | `string` | `"pubsub-to-bq"` | no |
| <a name="input_topic_name"></a> [topic\_name](#input\_topic\_name) | Name of the Pub/Sub topic | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bq_dataset_id"></a> [bq\_dataset\_id](#output\_bq\_dataset\_id) | BigQuery dataset ID |
| <a name="output_bq_table_id"></a> [bq\_table\_id](#output\_bq\_table\_id) | BigQuery table ID |
| <a name="output_cloud_run_url"></a> [cloud\_run\_url](#output\_cloud\_run\_url) | URL of the Cloud Run service |
| <a name="output_dead_letter_topic_id"></a> [dead\_letter\_topic\_id](#output\_dead\_letter\_topic\_id) | Dead-letter topic ID — messages that exceed max\_delivery\_attempts land here |
| <a name="output_subscription_id"></a> [subscription\_id](#output\_subscription\_id) | Pub/Sub subscription ID |
| <a name="output_topic_id"></a> [topic\_id](#output\_topic\_id) | Pub/Sub topic ID |
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
