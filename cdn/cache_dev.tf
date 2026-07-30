resource "fastly_service_vcl" "cache_dev" {
  activate           = true
  stage              = false
  default_host       = "ftp.r-l.o.s3.amazonaws.com"
  default_ttl        = 3600
  http3              = false
  name               = "cache-dev.ruby-lang.org"
  stale_if_error     = false
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
    port                  = 443
    prefer_ipv6           = false
    request_condition     = "always_false"
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

  condition {
    name      = "always_false"
    priority  = 10
    statement = "!req.url"
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

  # No logging_s3 counterpart: the production bucket ftp.r-l.o.log is an
  # access-log archive for cache, and dev traffic does not belong in it.
  logging_datadog {
    format            = file("${path.module}/logging/datadog_format.json")
    format_version    = 2
    name              = "Datadog"
    processing_region = "none"
    region            = "AP1"
    token             = var.datadog_token
  }

  # Shared with the cache service on purpose. Both define the same backend
  # names, so the generated identifiers (F_s3_amazonaws_com and friends) match,
  # and a canary is only worth running on the VCL production actually uses.
  vcl {
    content = file("${path.module}/vcl/cache.vcl")
    main    = true
    name    = "default"
  }
}
