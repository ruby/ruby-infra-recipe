# cdn

Terraform configuration for the Fastly services of ruby-lang.org. Each service lives in its own `.tf` file. Custom VCL is under `vcl/`, and the shared Datadog log format is `logging/datadog_format.json`.

The `ftp` service has been dormant since 2018 and is kept with `activate = false`. `ftp.ruby-lang.org` is actually served by the `cache` service.

The `vault.rubyci.org` service fronts the public `rubyci` S3 bucket (chkbuild logs). Bootstrap order: `terraform apply`, add the ACME challenge CNAME from `terraform output vault_rubyci_managed_dns_challenges` to `dns/dnsconfig.js` and push it, wait for certificate issuance, then add the `vault` CNAME (see the TODO in `dnsconfig.js`). Switching rubyci.org log links over to vault.rubyci.org happens in the ruby/rubyci repository.

## Usage

Credentials come from `~/.config/fastly/token.sh`, which must export `FASTLY_API_KEY` (global scope token), `TF_VAR_datadog_token`, `TF_VAR_logging_s3_access_key`, and `TF_VAR_logging_s3_secret_key`. The state backend also needs AWS credentials that can read and write `s3://ruby-lang-terraform-state`, supplied through any standard AWS mechanism such as `AWS_PROFILE` or `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`.

```
source ~/.config/fastly/token.sh
terraform init
terraform plan
terraform apply
```

State is stored in `s3://ruby-lang-terraform-state/cdn/terraform.tfstate` (ap-northeast-1, versioned, S3 native locking).
