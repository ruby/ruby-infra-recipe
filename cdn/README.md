# cdn

Terraform configuration for the Fastly services of ruby-lang.org. Each service lives in its own `.tf` file. Custom VCL is under `vcl/`, and the shared Datadog log format is `logging/datadog_format.json`.

The `ftp` service has been dormant since 2018 and is kept with `activate = false`. `ftp.ruby-lang.org` is actually served by the `cache` service.

## Usage

Credentials come from `~/.config/fastly/token.sh`, which must export `FASTLY_API_KEY` (global scope token), `TF_VAR_datadog_token`, `TF_VAR_logging_s3_access_key`, `TF_VAR_logging_s3_secret_key`, and `AWS_PROFILE` for the state backend.

```
source ~/.config/fastly/token.sh
terraform init
terraform plan
terraform apply
```

State is stored in `s3://ruby-lang-terraform-state/cdn/terraform.tfstate` (ap-northeast-1, versioned, S3 native locking).
