resource "fastly_service_vcl" "cache" {
  activate           = true
  stage              = false
  default_host       = "ftp.r-l.o.s3.amazonaws.com"
  default_ttl        = 3600
  http3              = false
  name               = "cache.ruby-lang.org"
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

  domain {
    comment = "For shielding"
    name    = "ftp.r-l.o.s3.amazonaws.com"
  }

  domain {
    name = "cache.ruby-lang.org"
  }

  domain {
    name = "ftp.ruby-lang.org"
  }

  logging_datadog {
    format            = file("${path.module}/logging/datadog_format.json")
    format_version    = 2
    name              = "Datadog"
    processing_region = "none"
    region            = "AP1"
    token             = var.datadog_token
  }

  logging_s3 {
    bucket_name       = "ftp.r-l.o.log"
    domain            = "s3.amazonaws.com"
    file_max_bytes    = 0
    format            = "%h %l %u %t \"%r\" %>s %b"
    format_version    = 2
    gzip_level        = 0
    message_type      = "classic"
    name              = "ftp.r-l.o.log"
    path              = "/"
    period            = 3600
    processing_region = "none"
    redundancy        = "standard"
    s3_access_key     = var.logging_s3_access_key
    s3_secret_key     = var.logging_s3_secret_key
    timestamp_format  = "%Y-%m-%dT%H:%M:%S.000"
  }

  vcl {
    content = file("${path.module}/vcl/cache.vcl")
    main    = true
    name    = "default"
  }
}
