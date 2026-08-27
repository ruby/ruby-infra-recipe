# docs.ruby-lang.org, served from S3 (aws_s3_bucket.docs in s3.tf) through
# the shape proven out on the docs-dev canary: the same backends and the same
# VCL file (vcl/docs.vcl), so the canary keeps exercising exactly what
# production serves. Backend selection goes through request_conditions on a
# header flag the custom VCL sets before #FASTLY recv (assigning req.backend
# in VCL would bypass shielding, see cache.tf). Every request the VCL lets
# through is flagged to one of the S3 backends; non-GET/HEAD methods get a
# synthetic 405 at the edge (the origin server is retired).
resource "fastly_service_vcl" "docs" {
  # docs_dev held the shielding domain below until this cutover, and Fastly
  # only allows a domain on one service: docs_dev must release it before this
  # service claims it within the same apply. Safe to drop after the cutover.
  depends_on = [fastly_service_vcl.docs_dev]

  activate           = true
  stage              = false
  # A shielded fetch needs a Host that is a domain of this service, so the
  # bucket endpoint doubles as default_host and as a domain below, the same
  # arrangement as cache.tf. The other backends override_host instead.
  default_host       = "docs.r-l.o.s3.amazonaws.com"
  default_ttl        = 60
  http3              = true
  name               = "docs.ruby-lang.org"
  stale_if_error     = true
  stale_if_error_ttl = 43200

  # The docs bucket: public/ root files, en, ja, and wasm (ruby.wasm binaries
  # for the RUN button). us-east-1, so shielded near it like the cache
  # service's S3 backend.
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
    name                  = "s3-docs"
    port                  = 443
    prefer_ipv6           = false
    request_condition     = "backend-is-docs-s3"
    shield                = "iad-va-us"
    ssl_cert_hostname     = "s3.amazonaws.com"
    ssl_check_cert        = true
    use_ssl               = true
    weight                = 100
  }

  # Doxygen stays in the rubyci bucket for now (step 1 of the migration);
  # dropping this backend and pointing doxygen.yml at the docs bucket's
  # capi/en/master/ prefix is step 2. The bucket name has no dots, so the
  # virtual-hosted endpoint works as the TLS hostname directly, the same
  # arrangement as logs_rubyci.tf. override_host is required: default_host
  # rewrites Host to the docs bucket endpoint, and S3 routes by Host, so
  # without it these requests would hit the docs bucket. Unshielded:
  # it refreshes every three hours and carries little traffic.
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
    name                  = "s3-rubyci-doxygen"
    override_host         = "rubyci.s3.ap-northeast-1.amazonaws.com"
    port                  = 443
    prefer_ipv6           = false
    request_condition     = "backend-is-doxygen-s3"
    ssl_cert_hostname     = "rubyci.s3.ap-northeast-1.amazonaws.com"
    ssl_check_cert        = true
    use_ssl               = true
    weight                = 100
  }

  condition {
    name      = "backend-is-docs-s3"
    priority  = 10
    statement = "req.http.X-Docs-Backend == \"s3\""
    type      = "REQUEST"
  }

  condition {
    name      = "backend-is-doxygen-s3"
    priority  = 10
    statement = "req.http.X-Docs-Backend == \"doxygen\""
    type      = "REQUEST"
  }

  # A shielded miss runs the logging endpoint at both POPs, so one request
  # becomes two events carrying the same byte count. The edge sets Fastly-FF when
  # it forwards to the shield, so this keeps the edge line, which is the one with
  # the client POP and the client-facing byte count. docs-dev shields through
  # this service too, since its default_host is the shielding domain below, so
  # this drops the docs-dev shield lines as well.
  condition {
    name      = "not-shield-request"
    priority  = 10
    statement = "!req.http.Fastly-FF"
    type      = "RESPONSE"
  }

  # What /ja/latest and /ja/master resolve to (the bucket holds no symlink
  # objects), and what the unreleased-version redirects key off. A release
  # updates these values and everything else follows.
  dictionary {
    name = "docs_versions"
  }

  domain {
    comment = "Legacy hostname; the VCL answers it with a redirect to docs"
    name    = "doc.ruby-lang.org"
  }

  domain {
    name = "docs.ruby-lang.org"
  }

  domain {
    comment = "For shielding"
    name    = "docs.r-l.o.s3.amazonaws.com"
  }

  gzip {
    content_types = ["text/html", "application/x-javascript", "text/css", "application/javascript", "text/javascript", "application/json", "application/vnd.ms-fontobject", "application/x-font-opentype", "application/x-font-truetype", "application/x-font-ttf", "application/xml", "font/eot", "font/opentype", "font/otf", "image/svg+xml", "image/vnd.microsoft.icon", "text/plain", "text/xml", "text/markdown"]
    extensions    = ["css", "js", "html", "eot", "ico", "otf", "ttf", "json", "svg", "md", "xml", "txt"]
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

  vcl {
    content = file("${path.module}/vcl/docs.vcl")
    main    = true
    name    = "default"
  }
}

# The same values as docs_dev_versions; a release updates both dictionaries
# out of band (API/UI). manage_items=false (the provider default, explicit
# here) opts out of reapplying these items when they drift, so a release's
# update is not reverted by the next apply; these are only the initial
# values.
resource "fastly_service_dictionary_items" "docs_versions" {
  service_id    = fastly_service_vcl.docs.id
  dictionary_id = one([for d in fastly_service_vcl.docs.dictionary : d.dictionary_id if d.name == "docs_versions"])
  manage_items  = false

  items = {
    latest = "4.0"
    master = "4.1"
  }
}
