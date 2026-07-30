# Install the chkbuild user's crontab. S3 uploads authenticate via the
# default credential chain (EC2 instance profile, or ~/.aws/credentials on
# non-EC2 hosts), so the crontab carries no AWS keys. node[:chkbuild] is
# populated by the ruby_script property provider in hocho.yml only for
# *.rubyci.org hosts; elsewhere the crontab is left untouched.
chkbuild = node[:chkbuild] || {}

if chkbuild[:nickname]
  # The Linux hosts run chkbuild as the dedicated chkbuild user; the macOS
  # hosts run everything as the hsbt login user (attributes.chkbuild.user).
  user = chkbuild[:user] || 'chkbuild'
  home = node[:platform] == 'darwin' ? "/Users/#{user}" : "/home/#{user}"
  # chkbuild checkout relative to the home directory (attributes.chkbuild.dir).
  dir = chkbuild[:dir] || 'chkbuild'

  # Non-EC2 hosts (aws_credentials_file in hosts.yml) cannot use an
  # instance profile, so they keep a long-lived key in ~/.aws/credentials.
  # The key pair reaches node[:chkbuild] only when CHKBUILD_AWS_* are set
  # at apply time; a credential-less apply skips this and leaves the
  # existing file untouched.
  if chkbuild[:aws_access_key_id] && chkbuild[:aws_secret_access_key]
    directory "#{home}/.aws" do
      owner user
      mode '700'
    end

    file "#{home}/.aws/credentials" do
      owner user
      mode '600'
      content [
        '[default]',
        "aws_access_key_id = #{chkbuild[:aws_access_key_id]}",
        "aws_secret_access_key = #{chkbuild[:aws_secret_access_key]}",
        '',
      ].join("\n")
    end
  end

  crontab_path = "#{home}/.crontab"

  # Interval per host is chosen so that one full chkbuild cycle (all branches)
  # plus ~15min headroom fits within it; chkbuild aborts when the previous run
  # still holds its lock, so an overlap loses a whole cycle.
  schedule = chkbuild[:schedule] || '30 */3 * * *'

  # e.g. crossruby builds cross targets with start-cross-rubyci, not plain
  # ruby branches with start-rubyci.
  command = chkbuild[:command] || 'start-rubyci'

  # Inline environment prepended to the build command
  # (attributes.chkbuild.command_env in hosts.yml), e.g. the android NDK
  # PATH prefix on crossruby. Unlike env above these go on the command line
  # because cron takes crontab environment lines literally; values that
  # reference $PATH need the shell expansion they get here.
  command_prefix = (chkbuild[:command_env] || {}).map {|key, value| "#{key}=#{value} " }.join

  lines = [
    'MAILTO=""',
    "RUBYCI_NICKNAME=#{chkbuild[:nickname]}",
  ]
  # Extra per-host environment lines (attributes.chkbuild.env in hosts.yml),
  # e.g. LC_ALL/DFLTCC on s390x, SSL_CERT_FILE on FreeBSD 15.
  (chkbuild[:env] || {}).each do |key, value|
    lines << "#{key}=#{value}"
  end
  lines << "#{schedule} cd ~/#{dir} && git pull origin master && #{command_prefix}~/.rbenv/shims/ruby #{command} && rm -rf tmp/build"
  # Additional chkbuild checkouts on the same host
  # (attributes.chkbuild.extra_builds in hosts.yml), e.g. ~/chkbuild-no-yjit
  # reporting as ubuntu-no-yjit. RUBYCI_NICKNAME is overridden per line
  # because the global assignment above names the primary build.
  (chkbuild[:extra_builds] || []).each do |extra|
    lines << "#{extra[:schedule]} cd ~/#{extra[:dir]} && git pull origin master && RUBYCI_NICKNAME=#{extra[:nickname]} #{command_prefix}~/.rbenv/shims/ruby #{command} && rm -rf tmp/build"
  end
  lines << ''

  # NOTE: no <<~ heredoc here; the mruby in mitamae <= 1.11 misparses it as
  # `content << ~CRON` and dies with NameError.
  file crontab_path do
    owner user
    mode '600'
    content lines.join("\n")
  end

  execute "crontab -u #{user} #{crontab_path}" do
    not_if "crontab -l -u #{user} 2>/dev/null | cmp -s - #{crontab_path}"
  end
else
  MItamae.logger.info "skipping chkbuild crontab (not a rubyci host)"
end
