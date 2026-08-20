# GitHub Actions OIDC roles for uploading to the docs bucket. Each producing
# repository assumes its own role, restricted to the prefix it owns, so the
# long-lived access keys the current server-side pipelines use are not
# reproduced here:
#
#   ruby/actions              en/* and capi/*   (rdoc; doxygen once it moves)
#   rurema/generated-documents ja/*             (bitclust HTML, daily)
#   ruby/docs.ruby-lang.org   whole bucket      (site chrome: root files plus
#                                                the en/ja version indexes)
#   rurema/run-ruby-wasm      wasm/*            (ruby.wasm for the RUN button)
#
# If the account already has the GitHub OIDC provider, import it instead of
# letting apply fail with EntityAlreadyExists:
#   terraform import aws_iam_openid_connect_provider.github \
#     arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # AWS validates GitHub's issuer against its own trusted CA store and
  # ignores the thumbprint for this provider, but the API requires one.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

locals {
  docs_bucket_arn = "arn:aws:s3:::docs.r-l.o"

  # role key => which repository refs may assume it, and which object
  # prefixes it may write. "*" means the whole bucket.
  docs_sync_repos = {
    ruby-actions = {
      subs     = ["repo:ruby/actions:ref:refs/heads/master"]
      prefixes = ["en/*", "capi/*"]
    }
    generated-documents = {
      subs     = ["repo:rurema/generated-documents:ref:refs/heads/main"]
      prefixes = ["ja/*"]
    }
    docs-ruby-lang-org = {
      subs     = ["repo:ruby/docs.ruby-lang.org:ref:refs/heads/master"]
      prefixes = ["*"]
    }
    run-ruby-wasm = {
      # The binaries are cut as GitHub Releases, so a release-triggered sync
      # workflow presents a tag ref, not the branch.
      subs     = ["repo:rurema/run-ruby-wasm:ref:refs/heads/main", "repo:rurema/run-ruby-wasm:ref:refs/tags/*"]
      prefixes = ["wasm/*"]
    }
  }
}

resource "aws_iam_role" "docs_sync" {
  for_each = local.docs_sync_repos

  name = "docs-sync-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          # StringLike so the tag-ref entries can carry a wildcard; entries
          # without one still match exactly.
          StringLike = {
            "token.actions.githubusercontent.com:sub" = each.value.subs
          }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "docs_sync" {
  for_each = local.docs_sync_repos

  name = "docs-sync-${each.key}"
  role = aws_iam_role.docs_sync[each.key].id

  # ListBucket is what lets `aws s3 sync` diff before uploading; the prefix
  # condition keeps each role from listing outside its own area. For "*"
  # roles the allowed prefixes are "" and "*": an unprefixed listing is
  # evaluated as the empty prefix, which a bare "*" alone would not cover.
  # DeleteObject is for `sync --delete`.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "List"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [local.docs_bucket_arn]
        Condition = {
          StringLike = {
            "s3:prefix" = contains(each.value.prefixes, "*") ? ["", "*"] : flatten([for p in each.value.prefixes : [trimsuffix(p, "/*"), p]])
          }
        }
      },
      {
        Sid    = "Write"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:DeleteObject"]
        Resource = [
          for p in each.value.prefixes : "${local.docs_bucket_arn}/${p}"
        ]
      },
    ]
  })
}

output "docs_sync_role_arns" {
  description = "Pass to aws-actions/configure-aws-credentials (role-to-assume) in each repository's sync workflow"
  value       = { for k, r in aws_iam_role.docs_sync : k => r.arn }
}
