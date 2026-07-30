# dns

DNSControl configuration for the Cloudflare zones. One directory per zone, each holding its own `dnsconfig.js` and `creds.json`.

- `rubyci.org/` — the CI hosts. Every rubyci host is resolved through DNS rather than `~/.ssh/config`, so a new host needs its record here before `bin/hocho apply`. The apex uses Cloudflare's CNAME flattening, which DNSControl expresses as `ALIAS`.
- `ruby-lang.org/` — the project zone.

The API tokens are zone-scoped and therefore different per zone, so each `creds.json` reads an environment variable named after its zone. `rubyci.org/creds.json` reads `CLOUDFLARE_API_TOKEN_RUBYCI` and `ruby-lang.org/creds.json` reads `CLOUDFLARE_API_TOKEN_RUBY_LANG_ORG`.

## rubyci.org

Applied from CI by `.github/workflows/dns.yml`: a pull request runs `dnscontrol preview`, and merging to `master` runs `dnscontrol push`. The token comes from the repository secret `CLOUDFLARE_API_TOKEN_RUBYCI`.

To preview locally:

```
source ~/.config/cloudflare/rubyci.org/token.sh
cd dns/rubyci.org
dnscontrol preview --creds creds.json
```

## ruby-lang.org

Not applied from CI. The zone is shared with other maintainers, so `push` is run by hand after the change is reviewed:

```
source ~/.config/cloudflare/ruby-lang.org/token.sh
cd dns/ruby-lang.org
dnscontrol preview --creds creds.json
dnscontrol push --creds creds.json
```
