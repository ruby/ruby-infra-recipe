resource "fastly_service_vcl" "cache_dev" {
  activate           = true
  stage              = false
  default_host       = "ftp.r-l.o.s3.amazonaws.com"
  default_ttl        = 3600
  http3              = true
  name               = "cache-dev.ruby-lang.org"
  stale_if_error     = true
  stale_if_error_ttl = 43200

  backend {
    address               = "cache-ruby-lang.herokuapp.com"
    auto_loadbalance      = false
    between_bytes_timeout = 10000
    connect_timeout       = 1000
    error_threshold       = 0
    first_byte_timeout    = 15000
    keepalive_time        = 0
    max_conn              = 200
    max_lifetime          = 0
    max_use               = 0
    name                  = "cache-ruby-lang.herokuapp.com"
    # Rewriting Host in custom VCL instead would send the shield a Host that is
    # not a domain of this service, which fails the shield fetch and only works
    # because the 5xx restart then bypasses the shield.
    override_host         = "cache-ruby-lang.herokuapp.com"
    port                  = 443
    prefer_ipv6           = false
    request_condition     = "url-is-index-app"
    shield                = "iad-va-us"
    ssl_cert_hostname     = "cache-ruby-lang.herokuapp.com"
    ssl_check_cert        = true
    use_ssl               = true
    weight                = 100
  }

  backend {
    address               = "s3-ap-northeast-1.amazonaws.com"
    auto_loadbalance      = false
    between_bytes_timeout = 10000
    connect_timeout       = 1000
    error_threshold       = 0
    first_byte_timeout    = 15000
    keepalive_time        = 0
    max_conn              = 200
    max_lifetime          = 0
    max_use               = 0
    name                  = "s3-sorah-pkg"
    port                  = 443
    prefer_ipv6           = false
    request_condition     = "url-is-sorah-deb"
    ssl_cert_hostname     = "s3-ap-northeast-1.amazonaws.com"
    ssl_check_cert        = true
    use_ssl               = true
    weight                = 100
  }

  backend {
    address               = "s3.amazonaws.com"
    auto_loadbalance      = false
    between_bytes_timeout = 10000
    connect_timeout       = 1000
    error_threshold       = 0
    first_byte_timeout    = 15000
    keepalive_time        = 0
    max_conn              = 200
    max_lifetime          = 0
    max_use               = 0
    name                  = "s3.amazonaws.com"
    port                  = 443
    prefer_ipv6           = false
    shield                = "iad-va-us"
    ssl_cert_hostname     = "s3.amazonaws.com"
    ssl_check_cert        = true
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

  # Replaces the always_false placeholder that used to keep this backend out of
  # the generated selection. Routing through a condition instead of assigning
  # req.backend in custom VCL is what lets the shield apply. The flag is set
  # before #FASTLY recv in vcl/cache.vcl, and again in vcl_fetch before the
  # restart that falls back to the index app.
  condition {
    name      = "url-is-index-app"
    priority  = 10
    statement = "req.http.X-Rlo-Use-Index-App"
    type      = "REQUEST"
  }

  condition {
    name      = "url-is-sorah-deb"
    priority  = 10
    statement = "req.url ~ \"^/~sorah/deb/\" || req.url ~ \"^/lab/sorah/deb/\""
    type      = "REQUEST"
  }

  # Reached only through the Fastly-provided domain. cache-dev.ruby-lang.org
  # never had a DNS record, so dropping it costs nothing and keeps the canary
  # off the ruby-lang.org zone.
  domain {
    name = "cache-rlo-dev.global.ssl.fastly.net"
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

  # Shared with the cache service again now that production runs the same VCL.
  # Split it back out into a cache_dev-only file when the next VCL change needs
  # a canary.
  vcl {
    content = file("${path.module}/vcl/cache.vcl")
    main    = true
    name    = "default"
  }
}
