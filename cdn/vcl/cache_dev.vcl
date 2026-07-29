sub vcl_recv {
#FASTLY recv

  // https://bugs.ruby-lang.org/projects/ruby/wiki/CDN-LabSorahDeb
  if (req.url ~ "^/~sorah/deb/") {
    set req.url = regsub(req.url, "^/~sorah/deb/", "/sorah-pkg/ruby/");
    set req.http.Host = "s3-ap-northeast-1.amazonaws.com";
  }
  if (req.url ~ "^/lab/sorah/deb/") {
    set req.url = regsub(req.url, "^/lab/sorah/deb/", "/sorah-pkg/ruby/");
    set req.http.Host = "s3-ap-northeast-1.amazonaws.com";
  }
  if (req.url == "/") {
    set req.http.X-Rlo-Use-Index-App = "1";
  }
  if (req.http.X-Rlo-Use-Index-App) {
    set req.backend = F_cache_ruby_lang_herokuapp_com;
    set req.http.Host = "cache-ruby-lang.herokuapp.com";
  }


  if (req.request != "HEAD" && req.request != "GET" && req.request != "FASTLYPURGE") {
    return(pass);
  }

  return(lookup);
}

sub vcl_fetch {
#FASTLY fetch

  if ((beresp.status == 500 || beresp.status == 503) && req.restarts < 1 && (req.request == "GET" || req.request == "HEAD")) {
    restart;
  }

  if(req.restarts > 0 ) {
    set beresp.http.Fastly-Restarts = req.restarts;
  }

  if (beresp.http.Set-Cookie) {
    set req.http.Fastly-Cachetype = "SETCOOKIE";
    return (pass);
  }

  if (beresp.http.Cache-Control ~ "private") {
    set req.http.Fastly-Cachetype = "PRIVATE";
    return (pass);
  }

  if (beresp.status == 500 || beresp.status == 503) {
    set req.http.Fastly-Cachetype = "ERROR";
    set beresp.ttl = 1s;
    set beresp.grace = 5s;
    return (deliver);
  }

  if (req.backend == F_s3_amazonaws_com && (req.url == "/" || beresp.status == 404) && !req.http.X-Rlo-Use-Index-App) {
    if (req.url ~ "/$" || req.url == "/") {
      set req.http.X-Rlo-Use-Index-App = "1";
      restart;
    }
  }
  if (req.http.X-Rlo-Use-Index-App) {
    set beresp.http.Surrogate-Key = "index-app";
  }
  
  if (req.url ~ "/(InRelease|Release|Sources|Packages|Contents).*") {
    # Debian repository metadata
    set beresp.ttl = 30s;
    set beresp.http.Surrogate-Key = "sorah-deb-meta";
  } else if (beresp.http.Expires || beresp.http.Surrogate-Control ~ "max-age" || beresp.http.Cache-Control ~"(s-maxage|max-age)") {
    # keep the ttl here
  } else {
    # apply the default ttl
    set beresp.ttl = 3600s;
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


