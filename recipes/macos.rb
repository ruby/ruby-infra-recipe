# macOS hosts (fuji, ringo): everything is set up for the hsbt login user;
# OS provisioning, Xcode CLT and the MacPorts installer are out of scope.

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
    user: 'hsbt',
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
%w[
  /Users/hsbt/.rbenv
  /Users/hsbt/.rbenv/plugins/ruby-build
  /Users/hsbt/.rbenv/plugins/rbenv-default-gems
].each do |repo|
  execute "remove stale deploy branch in #{repo}" do
    command "git -C #{repo} branch -D deploy"
    user 'hsbt'
    only_if "test \"$(git -C #{repo} rev-parse --abbrev-ref HEAD)\" != deploy && git -C #{repo} rev-parse -q --verify refs/heads/deploy"
  end
end

include_recipe 'rbenv::user'

# chkbuild checkouts under ~/Documents (the primary build plus any
# extra_builds from hosts.yml); each keeps itself up to date with the
# git pull in its cron line, so existing checkouts are left alone.
chkbuild = node[:chkbuild] || {}
dirs = [chkbuild[:dir], *(chkbuild[:extra_builds] || []).map { |extra| extra[:dir] }].compact
dirs.each do |dir|
  git "/Users/hsbt/#{dir}" do
    repository 'https://github.com/ruby/chkbuild'
    user 'hsbt'
    not_if "test -e /Users/hsbt/#{dir}"
  end
end

include_recipe 'chkbuild-cron'
