resource "fastly_service_vcl" "docs" {
  activate           = true
  stage              = false
  default_ttl        = 60
  http3              = true
  name               = "docs.ruby-lang.org"
  stale_if_error     = true
  stale_if_error_ttl = 43200

  backend {
    address               = "docs-origin.ruby-lang.org"
    auto_loadbalance      = false
    between_bytes_timeout = 10000
    connect_timeout       = 1000
    error_threshold       = 0
    first_byte_timeout    = 15000
    keepalive_time        = 0
    max_conn              = 200
    max_lifetime          = 0
    max_use               = 0
    name                  = "docs origin server"
    port                  = 443
    prefer_ipv6           = false
    shield                = "tyo-tokyo-jp"
    ssl_cert_hostname     = "docs-origin.ruby-lang.org"
    ssl_check_cert        = true
    use_ssl               = true
    weight                = 100
  }

  # A shielded miss runs the logging endpoint at both POPs, so one request
  # becomes two events carrying the same byte count. The edge sets Fastly-FF when
  # it forwards to the shield, so this keeps the edge line, which is the one with
  # the client POP and the client-facing byte count. This service has no custom
  # VCL, and a condition keeps it that way.
  condition {
    name      = "not-shield-request"
    priority  = 10
    statement = "!req.http.Fastly-FF"
    type      = "RESPONSE"
  }

  domain {
    name = "docs.ruby-lang.org"
  }

  gzip {
    content_types = ["text/html", "application/x-javascript", "text/css", "application/javascript", "text/javascript", "application/json", "application/vnd.ms-fontobject", "application/x-font-opentype", "application/x-font-truetype", "application/x-font-ttf", "application/xml", "font/eot", "font/opentype", "font/otf", "image/svg+xml", "image/vnd.microsoft.icon", "text/plain", "text/xml"]
    extensions    = ["css", "js", "html", "eot", "ico", "otf", "ttf", "json", "svg"]
    name          = "Default Gzip Policy"
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
}
