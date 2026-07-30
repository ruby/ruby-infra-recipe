# Imported, never created. Datadog ships `main` with the org, and applying this
# without `terraform import datadog_logs_index.main main` first would try to add
# a second index of the same name.
resource "datadog_logs_index" "main" {
  name = "main"

  # Everything that reaches the org. Narrowing this drops events that no other
  # index claims, silently.
  filter {
    query = ""
  }

  # No flex_retention_days. The Flex Tier is not in this org's contract, and
  # setting it answers 403 "Out of contract retentions are not authorized". The
  # S3 archive in archive.tf is what holds events past retention_days, and
  # reading them back means rehydrating.
  retention_days = var.index_retention_days

  # Fastly sends around 1.9M events a day, three quarters of it
  # docs.ruby-lang.org. A daily cap would drop the tail of a busy day instead of
  # billing for it, and the org is on a plan where volume is not the constraint.
  disable_daily_limit = true
}
