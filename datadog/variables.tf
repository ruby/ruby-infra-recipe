variable "archive_bucket" {
  description = "S3 bucket that holds the Datadog log archive"
  type        = string
  default     = "ruby-lang-log-archive"
}

variable "datadog_aws_account_id" {
  description = "Datadog's own AWS account ID, the trusted principal of the integration role"
  type        = string

  # Site specific, and the UI never shows it: it only hands out the external ID
  # and links to the docs, which fill this in client side. US1, US3, US5 and EU
  # share 464622532012, which is also the default baked into Datadog's
  # CloudFormation templates, but AP1 does not. The full per-site table lives in
  # aws_customer_access_id in DataDog/documentation, assets/scripts/config/
  # regions.config.js. Getting it wrong fails as "Datadog is unable to
  # authenticate with AWS role" with no AssumeRole event on this side, because a
  # trust policy rejection is logged in the caller's account.
  default = "417141415827"
}

variable "index_retention_days" {
  description = "Days events stay in the main index. Past this age the S3 archive is the only copy"
  type        = number

  # 15 is what this org's contract allows. Both 30 and any Flex Tier value are
  # rejected with 403 "Out of contract retentions are not authorized".
  default = 15
}

variable "archive_cold_after_days" {
  description = "Age at which archived objects move to GLACIER_IR"
  type        = number
  default     = 365
}
