# The read-only actions the AWS integration calls, taken from Datadog's own API
# rather than transcribed from the docs page, so refreshing it is a diff:
#
#   source ~/.config/datadog/token.sh
#   curl -s -H "DD-API-KEY: $DD_API_KEY" -H "DD-APPLICATION-KEY: $DD_APP_KEY" \
#     https://api.ap1.datadoghq.com/api/v2/integration/aws/iam_permissions |
#     jq '.data.attributes.permissions' > iam_permissions.json
#
# Granting these one at a time does not work. The integration health check walks
# the entire list and names a single missing action per run, so each fix reveals
# the next one and the account sits on a "missing critical IAM permissions"
# alert throughout.
#
# The AWS managed ReadOnlyAccess policy is the obvious shortcut and is the wrong
# trade in both directions. It is wider, because it grants data plane reads this
# list does not ask for, including s3:GetObject on every bucket in the account,
# which here means the chkbuild logs and the log archive. It is also narrower,
# because Datadog's list contains a handful of writes that a read-only policy by
# definition omits: events:CreateEventBus, logs:PutSubscriptionFilter,
# logs:DeleteSubscriptionFilter, s3:PutBucketNotification and sns:Publish, all of
# them for wiring up log forwarding. Attaching ReadOnlyAccess would therefore
# still leave the health check red while handing over more than it fixes.
locals {
  datadog_permissions = jsondecode(file("${path.module}/iam_permissions.json"))

  # The list minifies to a little over 27000 characters, and a role's inline
  # policies are capped at 10240 in aggregate, so no inline split can hold it.
  # Customer managed policies cap at 6144 each but attach up to 10 per role,
  # which is what makes a split work at all. IAM does not count whitespace, so
  # only the action names consume the budget.
  #
  # 180 per policy is the coarsest split that fits, at 5689 characters for the
  # largest chunk. Growth in the list adds chunks rather than enlarging them, so
  # the headroom only has to absorb longer action names, and the count has room
  # to roughly double before it reaches the 10 policy limit.
  datadog_permission_chunks = chunklist(local.datadog_permissions, 180)
}

resource "aws_iam_policy" "datadog_integration" {
  count = length(local.datadog_permission_chunks)

  name        = "DatadogIntegrationReadOnly-${count.index}"
  description = "Part ${count.index + 1} of Datadog's recommended AWS integration permissions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"

      # Every action here is account wide by nature: ListMetrics, the Describe
      # calls and the List calls take no resource qualifier, so narrowing this
      # would deny them rather than scope them.
      Action   = local.datadog_permission_chunks[count.index]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "datadog_integration" {
  count = length(local.datadog_permission_chunks)

  role       = aws_iam_role.datadog.name
  policy_arn = aws_iam_policy.datadog_integration[count.index].arn
}

# Resource collection asks for this on top of the list above, and the list does
# not mention it: with extended_collection on and this missing, the integration
# screen reports "Unable to collect the necessary resources due to missing
# permissions" and names this policy directly. It is what resolves an EC2 metric
# to a named rubyci host rather than an instance ID.
#
# Read-only, and narrower on the data plane than ReadOnlyAccess would be: the
# only S3 object actions in it are GetObjectAcl and GetObjectTagging, so it reads
# object metadata but never object contents. AWS maintains the contents, which is
# the point of using the managed policy rather than copying it.
resource "aws_iam_role_policy_attachment" "datadog_security_audit" {
  role       = aws_iam_role.datadog.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}
