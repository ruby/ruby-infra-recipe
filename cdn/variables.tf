variable "datadog_token" {
  description = "Datadog API key for Fastly logging endpoints"
  type        = string
  sensitive   = true
}

variable "logging_s3_access_key" {
  description = "AWS access key for the ftp.r-l.o.log S3 logging bucket"
  type        = string
  sensitive   = true
}

variable "logging_s3_secret_key" {
  description = "AWS secret key for the ftp.r-l.o.log S3 logging bucket"
  type        = string
  sensitive   = true
}
