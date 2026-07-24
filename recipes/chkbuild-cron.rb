# Install the chkbuild user's crontab. AWS credentials are injected into
# node[:chkbuild] by the ruby_script property provider in hocho.yml only
# when CHKBUILD_AWS_ACCESS_KEY_ID/CHKBUILD_AWS_SECRET_ACCESS_KEY are set
# at apply time; otherwise the crontab is left untouched.
chkbuild = node[:chkbuild] || {}

if chkbuild[:aws_access_key_id] && chkbuild[:aws_secret_access_key]
  crontab_path = "/home/chkbuild/.crontab"

  file crontab_path do
    owner 'chkbuild'
    mode '600'
    content <<~CRON
      MAILTO=""
      AWS_ACCESS_KEY_ID=#{chkbuild[:aws_access_key_id]}
      AWS_SECRET_ACCESS_KEY=#{chkbuild[:aws_secret_access_key]}
      RUBYCI_NICKNAME=#{chkbuild[:nickname]}
      30 */3 * * * cd ~/chkbuild && git pull origin master && ~/.rbenv/shims/ruby start-rubyci && rm -rf tmp/build
    CRON
  end

  execute "crontab -u chkbuild #{crontab_path}" do
    not_if "crontab -l -u chkbuild 2>/dev/null | cmp -s - #{crontab_path}"
  end
else
  MItamae.logger.info "skipping chkbuild crontab (no AWS credentials given)"
end
