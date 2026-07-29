resource "fastly_service_vcl" "docs_dev" {
  activate           = true
  stage              = false
  default_host       = "docs-origin.ruby-lang.org"
  default_ttl        = 60
  http3              = false
  name               = "docs-dev.ruby-lang.org"
  stale_if_error     = false
  stale_if_error_ttl = 43200

  backend {
    address               = "52.192.112.124"
    auto_loadbalance      = false
    between_bytes_timeout = 10000
    connect_timeout       = 1000
    error_threshold       = 0
    first_byte_timeout    = 15000
    keepalive_time        = 0
    max_conn              = 200
    max_lifetime          = 0
    max_use               = 0
    name                  = "addr 52.192.112.124"
    port                  = 443
    prefer_ipv6           = false
    ssl_cert_hostname     = "docs.ruby-lang.org"
    ssl_check_cert        = true
    use_ssl               = true
    weight                = 100
  }

  domain {
    name = "docs-dev.ruby-lang.org"
  }

  gzip {
    content_types = ["text/html", "application/x-javascript", "text/css", "application/javascript", "text/javascript", "application/json", "application/vnd.ms-fontobject", "application/x-font-opentype", "application/x-font-truetype", "application/x-font-ttf", "application/xml", "font/eot", "font/opentype", "font/otf", "image/svg+xml", "image/vnd.microsoft.icon", "text/plain", "text/xml"]
    extensions    = ["css", "js", "html", "eot", "ico", "otf", "ttf", "json", "svg"]
    name          = "Default Gzip Policy"
  }
}
