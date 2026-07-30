# Serves chkbuild logs from the public rubyci S3 bucket (ap-northeast-1)
# so that rubyci.org can link to logs.rubyci.org instead of S3 directly.
resource "fastly_service_vcl" "logs_rubyci" {
  activate           = true
  stage              = false
  default_ttl        = 300
  http3              = true
  name               = "logs.rubyci.org"
  stale_if_error     = true
  stale_if_error_ttl = 43200

  backend {
    address               = "rubyci.s3.ap-northeast-1.amazonaws.com"
    auto_loadbalance      = false
    between_bytes_timeout = 10000
    connect_timeout       = 1000
    error_threshold       = 0
    first_byte_timeout    = 15000
    keepalive_time        = 0
    max_conn              = 200
    max_lifetime          = 0
    max_use               = 0
    name                  = "rubyci S3 bucket"
    override_host         = "rubyci.s3.ap-northeast-1.amazonaws.com"
    port                  = 443
    prefer_ipv6           = false
    shield                = "tyo-tokyo-jp"
    ssl_cert_hostname     = "rubyci.s3.ap-northeast-1.amazonaws.com"
    ssl_check_cert        = true
    ssl_sni_hostname      = "rubyci.s3.ap-northeast-1.amazonaws.com"
    use_ssl               = true
    weight                = 100
  }

  # A shielded miss runs the logging endpoint at both POPs, so one request
  # becomes two events carrying the same byte count. The edge sets Fastly-FF when
  # it forwards to the shield, so this keeps the edge line, which is the one with
  # the client POP and the client-facing byte count.
  condition {
    name      = "not-shield-request"
    priority  = 10
    statement = "!req.http.Fastly-FF"
    type      = "RESPONSE"
  }

  domain {
    name = "logs.rubyci.org"
  }

  logging_datadog {
    format             = file("${path.module}/logging/datadog_format.json")
    format_version     = 2
    name               = "Datadog"
    processing_region  = "none"
    region             = "AP1"
    response_condition = "not-shield-request"
    token              = var.datadog_token
  }

  request_setting {
    bypass_busy_wait = false
    force_miss       = false
    force_ssl        = true
    max_stale_age    = 0
    name             = "Force TLS"
    timer_support    = false
    xff              = "append"
  }

  vcl {
    content = file("${path.module}/vcl/logs_rubyci.vcl")
    main    = true
    name    = "default"
  }
}

resource "fastly_tls_subscription" "logs_rubyci" {
  domains               = [one([for d in fastly_service_vcl.logs_rubyci.domain : d.name])]
  certificate_authority = "certainly"
  # "HTTP/3 & TLS v1.3". The account has no default TLS configuration, and the
  # older v1.2 ones used by ruby-lang.org do not advertise http/3.
  configuration_id = "cyAx0f8WAbapyNAT4TVOgw"
}

# CNAME records to add in dns/dnsconfig.js: the ACME challenge for issuance,
# then the domain itself pointing at the Fastly TLS endpoint.
output "logs_rubyci_managed_dns_challenges" {
  value = fastly_tls_subscription.logs_rubyci.managed_dns_challenges
}
