# datadog

Terraform configuration for the Datadog org (AP1) that receives the Fastly CDN logs from `cdn/`. `index.tf` holds the retention of the `main` index, `archive.tf` the S3 log archive and the AWS integration role it assumes, `integration_iam.tf` the read-only permissions on that role.

There are two copies, not two tiers. The `main` index keeps events queryable for 15 days, which is the ceiling this org's contract allows, and the archive holds the same events in S3 from ingest onwards. The Flex Tier is not in the contract: setting `flex_retention_days` at all answers 403, as does any `retention_days` above 15. Datadog has no setting that moves logs to S3 after N months, so the archive is written continuously and the index expiry is what decides when S3 holds the only copy. Reading past 15 days means rehydrating the archive back into an index.

The bucket lifecycle cools objects to `GLACIER_IR` after a year, long after the index has stopped covering them. That is the coldest storage class Datadog can read directly, so do not push it further to Deep Archive.

The archive is scoped to `source:fastly`. Heroku application logs stay out of it, since they carry more than CDN access data and nothing asked to keep them indefinitely.

## AWS integration permissions

`integration_iam.tf` grants `DatadogIntegrationRole` the read-only actions Datadog publishes at `/api/v2/integration/aws/iam_permissions`, kept verbatim in `iam_permissions.json`. Refresh it with the `curl` in the header of that file and review the diff; nothing else needs editing, because the split into policies is computed.

The split is forced. The list minifies past 27000 characters, a role's inline policies cap at 10240 in aggregate, and customer managed policies cap at 6144 but attach 10 to a role. `chunklist` cuts it at 180 actions, currently 5 policies named `DatadogIntegrationReadOnly-N`. Adding permissions adds policies rather than growing them, so the only ceiling that matters is 10.

Do not swap this for the AWS managed `ReadOnlyAccess`. It grants data plane reads the list never asks for, `s3:GetObject` on every bucket in the account among them, and it still omits the five writes Datadog uses to wire up log forwarding, so the health check stays red.

## Querying the archive

Anything older than the index retention lives only in S3. `athena.tf` registers it as `ruby_lang_logs.fastly` in the `ruby-lang-logs` workgroup. Partition projection covers `dt` and `hour`, so no crawler runs and no partition ever needs adding.

`service` is a column, not a partition. Datadog's path is only `dt=<date>/hour=<hour>`, and `partitioning_attributes` writes a sidecar index for Datadog's own archive search instead of an S3 prefix, so prune with `dt` and filter services in SQL. The opaque IDs map to host names in `cdn/*.tf`.

```sql
SELECT service, count(*) AS hits, sum(attributes.network.bytes_written) AS bytes
FROM ruby_lang_logs.fastly
WHERE dt BETWEEN '20260801' AND '20260831'
GROUP BY service
```

The declared columns are the ones worth querying. Datadog ships around 50 attributes and the SerDe ignores the undeclared ones, so add a column when a query needs it. Some of them come from Datadog rather than Fastly, including `attributes.http.url_details.path` and the parsed user agent.

Query results go to `athena-results/` in the same bucket and expire after 7 days. The lifecycle rule that cools the archive is scoped to `fastly/` so it leaves them alone.

## Usage

Credentials come from `~/.config/datadog/token.sh`, which must export `DD_API_KEY` and `DD_APP_KEY`. The Application Key needs the scopes for modifying log indexes, writing log archives, and editing the AWS integration. `DD_API_KEY` is an org API key and is unrelated to `TF_VAR_datadog_token` in `cdn/`, which is the intake key Fastly ships logs with.

Do not set up the AWS integration in the Datadog UI. `datadog_integration_aws_account` creates the registration and generates its own external ID, and the UI flow would both duplicate the registration and, through its CloudFormation template, create an IAM role that collides with `aws_iam_role.datadog`.

The state backend and the S3 resources need AWS credentials for the ruby-lang account. `AWS_PROFILE=ruby-lang` works here.

The `main` index already exists, so import it before the first plan.

```
source ~/.config/datadog/token.sh
terraform init
terraform import datadog_logs_index.main main
terraform plan
```

Removing `logging_s3` from `cdn/cache.tf` waits until this archive has objects in the bucket. The other order leaves a gap where neither sink keeps the access logs.

State is stored in `s3://ruby-lang-terraform-state/datadog/terraform.tfstate` (ap-northeast-1, versioned, S3 native locking).
