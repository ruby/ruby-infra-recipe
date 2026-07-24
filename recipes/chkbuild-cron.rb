# Install the chkbuild user's crontab. AWS credentials are injected into
# node[:chkbuild] by the ruby_script property provider in hocho.yml only
# when CHKBUILD_AWS_ACCESS_KEY_ID/CHKBUILD_AWS_SECRET_ACCESS_KEY are set
# at apply time; otherwise the crontab is left untouched.
chkbuild = node[:chkbuild] || {}

if chkbuild[:aws_access_key_id] && chkbuild[:aws_secret_access_key]
  crontab_path = "/home/chkbuild/.crontab"

  # Interval per host is chosen so that one full chkbuild cycle (all branches)
  # plus ~15min headroom fits within it; chkbuild aborts when the previous run
  # still holds its lock, so an overlap loses a whole cycle.
  schedule = chkbuild[:schedule] || '30 */3 * * *'

  lines = [
    'MAILTO=""',
    "AWS_ACCESS_KEY_ID=#{chkbuild[:aws_access_key_id]}",
    "AWS_SECRET_ACCESS_KEY=#{chkbuild[:aws_secret_access_key]}",
    "RUBYCI_NICKNAME=#{chkbuild[:nickname]}",
  ]
  if node[:platform] == 'freebsd' && node[:platform_version].to_i >= 15
    # ruby built on FreeBSD 15 (pkgbase) does not find the system CA bundle
    # by itself and every https access fails without this. Not needed on
    # FreeBSD 14 and earlier.
    lines << 'SSL_CERT_FILE=/usr/local/share/certs/ca-root-nss.crt'
  end
  lines << "#{schedule} cd ~/chkbuild && git pull origin master && ~/.rbenv/shims/ruby start-rubyci && rm -rf tmp/build"
  lines << ''

  # NOTE: no <<~ heredoc here; the mruby in mitamae <= 1.11 misparses it as
  # `content << ~CRON` and dies with NameError.
  file crontab_path do
    owner 'chkbuild'
    mode '600'
    content lines.join("\n")
  end

  execute "crontab -u chkbuild #{crontab_path}" do
    not_if "crontab -l -u chkbuild 2>/dev/null | cmp -s - #{crontab_path}"
  end
else
  MItamae.logger.info "skipping chkbuild crontab (no AWS credentials given)"
end
