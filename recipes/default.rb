include_recipe "hostname"
include_recipe "setup-users"

user 'chkbuild' do
  case node[:platform]
  when 'debian', 'ubuntu'
    shell '/bin/bash'
  end
end

directory '/home/chkbuild' do
  mode  '755'
  owner 'chkbuild'
end

if node[:platform] == 'opensuse'
  group = 'users'
else
  group = 'chkbuild'
end

node.reverse_merge!(
  rbenv: {
    user: 'chkbuild',
    group: group,
    global: '3.4.8',
    versions: %w[
      3.4.8
    ],
    install_development_dependency: true,
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

# mitamae's git resource cannot update a repo whose HEAD was moved off the
# deploy branch (e.g. by a manual `git checkout master`): the stale deploy
# branch makes `git checkout <sha> -b deploy` fail. Drop it beforehand.
%w[
  /home/chkbuild/.rbenv
  /home/chkbuild/.rbenv/plugins/ruby-build
  /home/chkbuild/.rbenv/plugins/rbenv-default-gems
].each do |repo|
  execute "remove stale deploy branch in #{repo}" do
    command "git -C #{repo} branch -D deploy"
    user 'chkbuild'
    only_if "test \"$(git -C #{repo} rev-parse --abbrev-ref HEAD)\" != deploy && git -C #{repo} rev-parse -q --verify refs/heads/deploy"
  end
end

include_recipe 'rbenv::user'

file "/home/chkbuild/.bash_profile" do
  action :create
  owner 'chkbuild'
  mode '644'
  content <<-EOF
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
  EOF
end

git "chkbuild" do
  repository "https://github.com/ruby/chkbuild"
  user "chkbuild"
  not_if "test -e /home/chkbuild/chkbuild"
end

case node[:platform]
when 'debian'
  package 'cron'
when 'fedora', 'amazon'
  package 'cronie'
  package 'cronie-anacron'
  service 'crond' do
    action [:enable, :start]
  end
  package 'patch'
when 'redhat', 'openbsd', 'opensuse'
  package 'patch'
when 'arch'
  package 'cronie'
  package 'vi' # for crontab -e
  service 'cronie' do
    action [:enable, :start]
  end
  package 'inetutils' # for ruby/spec/ruby/library/socket/socket/gethostname_spec.rb
when 'gentoo'
  package 'fcron'
  service 'fcron' do
    action [:enable, :start]
  end
end

# The host running start-cross-rubyci needs the cross toolchains (cross gcc,
# emscripten, WASI SDK, android NDK) on top of the common setup above.
if (node[:chkbuild] || {})[:command] == 'start-cross-rubyci'
  include_recipe "crossruby"
end

include_recipe "chkbuild-cron"
