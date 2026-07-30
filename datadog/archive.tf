data "aws_caller_identity" "current" {}

locals {
  # Referenced by both the role and the integration. Pointing the integration at
  # aws_iam_role.datadog.name instead would be a cycle, because the role's trust
  # policy needs the external ID that the integration generates.
  datadog_role_name = "DatadogIntegrationRole"
}

# Datadog writes this archive continuously, from ingest. There is no "move to S3
# after N months" knob, so the bucket holds every event from day one and the
# index retention decides when it stops being the second copy and becomes the
# only one.
resource "aws_s3_bucket" "log_archive" {
  bucket = var.archive_bucket
}

resource "aws_s3_bucket_public_access_block" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  rule {
    id     = "cold-once-the-index-expires"
    status = "Enabled"

    # Scoped to the archive, so Athena query results under athena-results/ are
    # not dragged into Glacier by the same rule.
    filter {
      prefix = "fastly/"
    }

    # Glacier Instant Retrieval is the coldest class Datadog still reads
    # directly. Flexible Retrieval and Deep Archive need an S3 restore first,
    # which is why the old chkbuild logs in the rubyci bucket answer 403.
    transition {
      days          = var.archive_cold_after_days
      storage_class = "GLACIER_IR"
    }
  }

  rule {
    id     = "drop-athena-results"
    status = "Enabled"

    filter {
      prefix = "athena-results/"
    }

    expiration {
      days = 7
    }
  }
}

data "aws_iam_policy_document" "datadog_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.datadog_aws_account_id]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [datadog_integration_aws_account.main.auth_config.aws_auth_config_role.external_id]
    }
  }
}

resource "aws_iam_role" "datadog" {
  name               = local.datadog_role_name
  assume_role_policy = data.aws_iam_policy_document.datadog_assume_role.json
}

data "aws_iam_policy_document" "log_archive" {
  statement {
    effect = "Allow"

    # PutObject writes the archive. GetObject and ListBucket are what archive
    # search and rehydration read it back with.
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["${aws_s3_bucket.log_archive.arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.log_archive.arn]
  }

  # This policy stays scoped to the archive bucket. The cloudwatch:ListMetrics
  # statement that used to sit here was a stopgap against the integration health
  # check, and integration_iam.tf now covers it under cloudwatch:List* along with
  # the rest of Datadog's list.
}

resource "aws_iam_role_policy" "log_archive" {
  name   = "DatadogLogArchive"
  role   = aws_iam_role.datadog.id
  policy = data.aws_iam_policy_document.log_archive.json
}

# The archive authenticates by assuming the role above, and Datadog only allows
# that for an account registered here. The role now carries Datadog's full read
# only list from integration_iam.tf, so metrics and resource collection are on
# and this is the fleet's host level monitoring: the roughly 26 rubyci EC2 hosts
# in hosts.yml have no other source of CPU, disk or network metrics.
resource "datadog_integration_aws_account" "main" {
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_partition  = "aws"

  # Optional and computed. Leaving it out makes every plan show
  # `[] -> (known after apply)`, which drags the external ID and the role's trust
  # policy into a diff that never settles.
  account_tags = []

  # Every EC2 instance in the account is here: a sweep of all 17 enabled regions
  # found 26 in ap-northeast-1 and none anywhere else. hosts.yml carries no
  # region of its own, it is a list of host names, so AWS is the thing to re-check
  # if the fleet ever spreads. Listing regions that hold nothing would only add
  # empty CloudWatch polls.
  aws_regions {
    include_only = ["ap-northeast-1"]
  }

  auth_config {
    aws_auth_config_role {
      role_name = local.datadog_role_name
    }
  }

  logs_config {
    lambda_forwarder {}
  }

  metrics_config {
    enabled = true

    # Empty is not "no filtering": the provider reads it as the default
    # exclude_only of AWS/SQS, AWS/ElasticMapReduce and AWS/Usage. None of the
    # three is in use here, so the effect is every namespace this account has.
    namespace_filters {}
  }

  # Adds configuration and tags to the resources behind the metrics, which is
  # what makes an EC2 metric resolve to a named rubyci host instead of an
  # instance ID. Both this and metrics_config.enabled default to true in the
  # provider; they were only pinned off while the role held S3 permissions and
  # nothing else.
  resources_config {
    extended_collection = true
  }

  traces_config {
    xray_services {}
  }
}

resource "datadog_logs_archive" "fastly" {
  name  = "fastly-cdn-logs"
  query = "source:fastly"

  # Keeps the Datadog tags on the archived events, so a rehydration comes back
  # with the same facets as the original.
  include_tags = true

  # Explicitly empty, not omitted: omitting it leaves whatever the API already
  # holds, and Terraform reports a successful update while the archive keeps the
  # old value.
  partitioning_attributes = []

  # Partitioning is off because it does not partition the S3 path, which stays
  # dt=<date>/hour=<hour>; it writes a `*.idx.<base64 attr>.partitionMetadata.zst`
  # sidecar next to each object for Datadog's own archive search. Athena reads
  # every file under the prefix and only skips names starting with `_` or `.`,
  # so those sidecars would reach the JSON SerDe as zstd binary. Athena is the
  # primary path for anything older than the index retention, so it wins.

  s3_archive {
    account_id = data.aws_caller_identity.current.account_id
    bucket     = aws_s3_bucket.log_archive.id
    path       = "fastly"
    role_name  = local.datadog_role_name

    # The lifecycle rule cools these objects down later. Writing them cold from
    # the start would only slow down the window the index still covers.
    storage_class = "STANDARD"
  }

  # Datadog verifies write access when the archive is created, so the role needs
  # its policy and its registration first.
  depends_on = [
    aws_iam_role_policy.log_archive,
    datadog_integration_aws_account.main,
  ]
}
