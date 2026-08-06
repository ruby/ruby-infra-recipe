sub vcl_recv {

  # ---- S3 backend routing and rewrites (docs-dev canary) ----
  # Runs before #FASTLY recv so the generated backend-selection code
  # (request_condition) can see the X-Docs-Backend flag, same as cache.vcl.
  # Client-visible URLs never change here: everything except the synthetic
  # redirects (error 601/602) is an internal rewrite, and the cache key is
  # the rewritten URL.

  declare local var.lang STRING;
  declare local var.ver STRING;
  declare local var.rest STRING;

  if (req.request == "HEAD" || req.request == "GET") {

    # Surrogate-Key and redirects are computed from what the client asked
    # for, so keep the pre-rewrite URL. It survives restarts (markdown
    # fallback below), so only set it on the first pass.
    if (!req.http.X-Orig-Url) {
      set req.http.X-Orig-Url = req.url;
    }

    # Vary: Accept is served on the negotiable /ja/ pages below. Normalize
    # Accept to two values first so the variants cannot explode per client.
    if (req.url ~ "^/ja/") {
      if (req.http.Accept ~ "text/markdown") {
        set req.http.Accept = "text/markdown";
      } else {
        unset req.http.Accept;
      }
    }

    # ---- redirects, same rules and order as the nginx origin ----
    if (req.url ~ "^/en/trunk(.*)$") {
      set req.http.X-Redirect-Location = "https://docs.ruby-lang.org/en/master" re.group.1;
      error 601;
    }
    # https://github.com/ruby/docs.ruby-lang.org/issues/130
    if (req.url ~ "^/en/([^/]+)/doc/(.*)$") {
      set req.http.X-Redirect-Location = "/en/" re.group.1 "/" re.group.2;
      error 601;
    }
    # 2.8.0 was renamed to 3.0.0, and the directory is 3.0
    if (req.url ~ "^/(en|ja)/(2\.8\.0|3\.0\.0)(.*)$") {
      set req.http.X-Redirect-Location = "/" re.group.1 "/3.0" re.group.3;
      error 601;
    }
    # Old rurema-search /ja/search/query:WORD/ URLs; ?q= keeps the
    # percent-encoding because req.url is still encoded here.
    if (req.url ~ "^/ja/search/" && req.url ~ "query:") {
      if (req.url ~ "^/ja/search/(?:[^?]*?/)??query:([^/?]+)") {
        set req.http.X-Redirect-Location = "/ja/search/?q=" re.group.1;
      } else {
        set req.http.X-Redirect-Location = "/ja/search/";
      }
      error 601;
    }

    # The unreleased version is not public until the release: ja/master
    # pages point at en/<devel> through their [rdoc] links (which only
    # exists as en/master), and ja/<devel> itself is not linked from the
    # version index. Both go to the master alias with a temporary redirect
    # that disappears once the docs_versions dictionary moves at release.
    if (req.url ~ "^/(en|ja)/([^/?]+)(/[^?]*)?$") {
      set var.lang = re.group.1;
      set var.ver = re.group.2;
      set var.rest = re.group.3;
      if (var.ver == table.lookup(docs_versions, "master")) {
        if (var.rest == "") {
          set var.rest = "/";
        }
        set req.http.X-Redirect-Location = "/" var.lang "/master" var.rest;
        error 602;
      }
    }

    # S3 interprets query strings as API parameters and the static site
    # never varies on them (/ja/search/?q= is read by client-side JS), so
    # drop them from the cache key and the backend request.
    set req.url = req.url.path;

    # Directory-looking URL without the trailing slash: redirect to the
    # slash form, like nginx did for directories. Every real page has an
    # extension, so no dot in the last segment is a safe heuristic.
    if (req.url ~ "^/(en|ja|capi)(/|$)" && req.url !~ "\.[^/]+$" && req.url !~ "/$") {
      set req.http.X-Redirect-Location = req.url "/";
      error 601;
    }

    # /ja/latest and /ja/master have no symlink objects in the bucket;
    # rewrite them to the real version from the docs_versions dictionary.
    # The client URL stays on the alias, and a release only needs a
    # dictionary update.
    if (req.url ~ "^/ja/(latest|master)/") {
      set req.http.X-Docs-Symlink = re.group.1;
      set req.http.X-Docs-Version = table.lookup(docs_versions, req.http.X-Docs-Symlink);
      if (req.http.X-Docs-Version) {
        set req.url = regsub(req.url, "^/ja/(latest|master)/", "/ja/" req.http.X-Docs-Version "/");
      }
    }

    # Directory index: a trailing-slash URL fetches index.html from S3
    # (the nginx index directive, as an internal rewrite).
    if (req.url ~ "/$") {
      set req.url = req.url "index.html";
    }

    # ---- Markdown content negotiation (ja only, where .md twins exist) ----
    # Accept: text/markdown on an .html URL fetches the .md twin instead.
    # Pages without a twin (generated indexes, frozen RD versions) fall
    # back: vcl_fetch restarts with X-Md-Negotiate=fallback on the 404 and
    # this block then restores the .html URL.
    if (req.http.X-Md-Negotiate == "fallback") {
      if (req.url ~ "\.md$") {
        set req.url = regsub(req.url, "\.md$", ".html");
      }
    } else if (req.url ~ "^/ja/" && req.url ~ "\.html$" && req.http.Accept == "text/markdown") {
      set req.http.X-Md-Negotiate = "md";
      set req.url = regsub(req.url, "\.html$", ".md");
    }

    # ---- backend selection flags, read by the request_conditions ----
    if (req.url ~ "^/capi/en/master/") {
      set req.http.X-Docs-Backend = "doxygen";
      set req.url = regsub(req.url, "^/capi/en/master/", "/doxygen-latest-html/");
    } else {
      # Narrow this per prefix to move paths over one at a time; anything
      # unflagged still goes to docs-origin.
      set req.http.X-Docs-Backend = "s3";
    }
  }

#FASTLY recv

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

  # A negotiated .md that does not exist falls back to the .html twin
  # (403 is what public-read S3 answers for a missing key).
  if ((beresp.status == 403 || beresp.status == 404) && req.http.X-Md-Negotiate == "md" && req.restarts < 3) {
    set req.http.X-Md-Negotiate = "fallback";
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

  if (req.http.X-Docs-Backend) {
    # The public-read policy only grants GetObject, so a missing key is
    # AccessDenied. Serve it as 404 with a short negative-cache TTL.
    if (beresp.status == 403) {
      set beresp.status = 404;
      set beresp.response = "Not Found";
    }
    if (beresp.status == 404) {
      set beresp.ttl = 60s;
    }

    # Cache-Control and Surrogate-Key move here from the nginx origin; the
    # fastly-purge-key key scheme is unchanged. An alias URL (/ja/latest)
    # and its real version share one object after the rewrite, so the key
    # carries both names: bc-static-all purges ja/<version> as well as
    # ja/latest and ja/master.
    if (req.http.X-Orig-Url ~ "^/capi/en/master/") {
      set beresp.http.Surrogate-Key = "doxygen-latest-html";
    } else if (req.url ~ "^/(en|ja)/([^/?]+)/") {
      set beresp.http.Surrogate-Key = "docs " re.group.1 " " re.group.2 " " re.group.1 "/" re.group.2;
      if (req.http.X-Docs-Symlink) {
        set beresp.http.Surrogate-Key = beresp.http.Surrogate-Key " ja/" req.http.X-Docs-Symlink;
      }
    } else {
      set beresp.http.Surrogate-Key = "index";
    }
    set beresp.http.Cache-Control = "public, max-age=43200, s-maxage=172800, stale-while-revalidate=86400, stale-if-error=604800";

    # The generated Markdown twins (given text/markdown by nginx since
    # ruby/docs.ruby-lang.org#200; aws s3 sync cannot guess a type for .md).
    if (req.url ~ "\.md$") {
      set beresp.http.Content-Type = "text/markdown; charset=utf-8";
    }

    # The negotiable pages answer differently by Accept, so downstream
    # caches need Vary (the edge already keys on the rewritten URL plus
    # the normalized Accept).
    if (req.http.X-Orig-Url ~ "^/ja/" && req.url ~ "\.(html|md)$") {
      set beresp.http.Vary = "Accept";
    }

    unset beresp.http.x-amz-id-2;
    unset beresp.http.x-amz-request-id;
    unset beresp.http.x-amz-version-id;
    unset beresp.http.x-amz-delete-marker;
    unset beresp.http.x-amz-server-side-encryption;
    unset beresp.http.Server;
  }

  if (beresp.http.Expires || beresp.http.Surrogate-Control ~ "max-age" || beresp.http.Cache-Control ~"(s-maxage|max-age)") {
    # keep the ttl here
  } else {
    # apply the default ttl, which must match default_ttl in docs_dev.tf
    set beresp.ttl = 60s;
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

  # Synthetic redirects from vcl_recv: 601 is the permanent kind (the
  # nginx return 301 rules), 602 the temporary kind (unreleased-version
  # aliases, gone once the docs_versions dictionary moves at a release).
  if (obj.status == 601 || obj.status == 602) {
    if (obj.status == 601) {
      set obj.status = 301;
      set obj.response = "Moved Permanently";
      set obj.http.Cache-Control = "public, max-age=3600";
    } else {
      set obj.status = 302;
      set obj.response = "Found";
      set obj.http.Cache-Control = "public, max-age=60";
    }
    set obj.http.Location = req.http.X-Redirect-Location;
    synthetic "";
    return(deliver);
  }

  # The nginx error_page 50x equivalent.
  if (obj.status >= 500 && obj.status < 600) {
    set obj.http.Content-Type = "text/html; charset=utf-8";
    synthetic {"<!DOCTYPE html><html><head><title>Error</title></head><body><h1>An error occurred.</h1></body></html>"};
    return(deliver);
  }
}

sub vcl_pass {
#FASTLY pass
}
