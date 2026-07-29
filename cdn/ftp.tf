# Dormant since 2018. ftp.ruby-lang.org is served by the cache service;
# activating this service would conflict with that domain.
resource "fastly_service_vcl" "ftp" {
  activate           = false
  stage              = false
  comment            = ""
  default_host       = "ftp.r-l.o.s3.amazonaws.com"
  default_ttl        = 3600
  http3              = false
  name               = "ftp.ruby-lang.org"
  stale_if_error     = false
  stale_if_error_ttl = 43200

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
    name                  = "ftp.r-l.o"
    port                  = 443
    prefer_ipv6           = false
    ssl_cert_hostname     = "s3.amazonaws.com"
    ssl_check_cert        = true
    use_ssl               = true
    weight                = 100
  }

  domain {
    name = "ftp.ruby-lang.org"
  }
}
