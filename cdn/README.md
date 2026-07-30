# cdn

Terraform configuration for the Fastly services of ruby-lang.org. Each service lives in its own `.tf` file. Custom VCL is under `vcl/`, and the shared Datadog log format is `logging/datadog_format.json`.

The `ftp` service has been dormant since 2018 and is kept with `activate = false`. `ftp.ruby-lang.org` is actually served by the `cache` service.

The `logs.rubyci.org` service fronts the public `rubyci` S3 bucket (chkbuild logs). Switching rubyci.org log links over to it happens in the ruby/rubyci repository.

Bootstrapping a domain on a new TLS subscription takes three steps, because the ACME challenge has to resolve before Fastly will issue: `terraform apply`, then add the challenge CNAME from `terraform output logs_rubyci_managed_dns_challenges` to `dns/rubyci.org/dnsconfig.js` and push it, then add the domain CNAME once the subscription reaches `issued`. The challenge record stays in `dnsconfig.js` afterwards, since renewal reuses it.

Two things about the Fastly API token. It needs the TLS management permission, which is only settable when the automation token is created; without it `fastly_tls_subscription` fails with a bare `403 - Forbidden`. And this account has no default TLS configuration, so `configuration_id` is required, which also decides the CNAME target the domain points at.

## Usage

Credentials come from `~/.config/fastly/token.sh`, which must export `FASTLY_API_KEY` (global scope token), `TF_VAR_datadog_token`, `TF_VAR_logging_s3_access_key`, and `TF_VAR_logging_s3_secret_key`. The state backend also needs AWS credentials that can read and write `s3://ruby-lang-terraform-state`, supplied through any standard AWS mechanism such as `AWS_PROFILE` or `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`.

```
source ~/.config/fastly/token.sh
terraform init
terraform plan
terraform apply
```

State is stored in `s3://ruby-lang-terraform-state/cdn/terraform.tfstate` (ap-northeast-1, versioned, S3 native locking).
