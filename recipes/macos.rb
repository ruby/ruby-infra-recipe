# macOS hosts (fuji, ringo): OS provisioning, Xcode CLT and the MacPorts
# installer are out of scope.
#
# The user owning everything (rbenv, checkouts, crontab) comes from
# attributes.chkbuild.user in hosts.yml (currently hsbt), so switching to a
# dedicated chkbuild user later only needs that attribute changed; the user
# itself must already exist.
chkbuild = node[:chkbuild] || {}
user = chkbuild[:user] || 'chkbuild'
home = "/Users/#{user}"

# Build dependencies for the chkbuild ruby builds, from MacPorts.
# start-rubyci puts /opt/local/bin on PATH and configures with
# --with-openssl-dir=/opt/local --with-libyaml-dir=/opt/local;
# curl-ca-bundle provides /opt/local/etc/openssl/cert.pem for the
# https-facing tests and rust is for YJIT. setrequested protects ports
# that originally arrived as dependencies (and would otherwise be
# reclaimed by `port reclaim`) once they are declared here.
port = '/opt/local/bin/port'
%w[
  autoconf
  automake
  bison
  curl-ca-bundle
  gdbm
  libtool
  libyaml
  openssl
  rust
].each do |pkg|
  execute "#{port} -N install #{pkg}" do
    not_if "#{port} -q installed #{pkg} | grep -q '(active)'"
  end

  execute "#{port} setrequested #{pkg}" do
    not_if "#{port} echo requested | grep -q '^#{pkg} '"
  end
end

node.reverse_merge!(
  rbenv: {
    user: user,
    group: 'staff',
    global: '3.4.8',
    versions: %w[
      3.4.8
    ],
    # Build dependencies come from MacPorts above; the plugin's dependency
    # recipe only knows Linux package managers.
    install_dependency: false,
  },
  'ruby-build': {
    build_envs: {
      'RUBY_CONFIGURE_OPTS': '--disable-install-doc --disable-dtrace',
    },
  },
  'rbenv-default-gems': {
    'default-gems': [
      'aws-sdk-s3',
    ],
  },
)

# Same workaround as default.rb: mitamae's git resource cannot update a
# repo whose HEAD was moved off the deploy branch.
%W[
  #{home}/.rbenv
  #{home}/.rbenv/plugins/ruby-build
  #{home}/.rbenv/plugins/rbenv-default-gems
].each do |repo|
  execute "remove stale deploy branch in #{repo}" do
    command "git -C #{repo} branch -D deploy"
    user user
    only_if "test \"$(git -C #{repo} rev-parse --abbrev-ref HEAD)\" != deploy && git -C #{repo} rev-parse -q --verify refs/heads/deploy"
  end
end

include_recipe 'rbenv::user'

# chkbuild checkouts under ~/Documents (the primary build plus any
# extra_builds from hosts.yml); each keeps itself up to date with the
# git pull in its cron line, so existing checkouts are left alone.
dirs = [chkbuild[:dir], *(chkbuild[:extra_builds] || []).map { |extra| extra[:dir] }].compact
dirs.each do |dir|
  git "#{home}/#{dir}" do
    repository 'https://github.com/ruby/chkbuild'
    user user
    not_if "test -e #{home}/#{dir}"
  end
end

include_recipe 'chkbuild-cron'
