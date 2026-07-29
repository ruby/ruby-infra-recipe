sub vcl_recv {
#FASTLY recv

  if (req.request == "FASTLYPURGE") {
    set req.http.Fastly-Purge-Requires-Auth = "1";
  }

  if (req.request != "HEAD" && req.request != "GET" && req.request != "FASTLYPURGE") {
    return(pass);
  }

  return(lookup);
}

sub vcl_fetch {
#FASTLY fetch

  set beresp.stale_while_revalidate = 60s;

  if (req.url ~ "/log/\d{8}T\d{6}Z\.") {
    # Timestamped chkbuild logs are immutable
    set beresp.ttl = 31536000s;
  } else {
    # cur/, summary pages and other keys are overwritten by chkbuild
    set beresp.ttl = 300s;
  }

  return(deliver);
}

sub vcl_hit {
#FASTLY hit

  if (!obj.cacheable) {
    return(pass);
  }
  return(deliver);
}

sub vcl_miss {
#FASTLY miss
  return(fetch);
}

sub vcl_deliver {
#FASTLY deliver
  return(deliver);
}

sub vcl_error {
#FASTLY error
}

sub vcl_pass {
#FASTLY pass
}
