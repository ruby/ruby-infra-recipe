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
    global: '3.1.3',
    versions: %w[
      3.1.3
    ],
    install_development_dependency: true,
  },
  'ruby-build': {
    build_envs: {
      'RUBY_CONFIGURE_OPTS': '--disable-dtrace',
    },
  },
  'rbenv-default-gems': {
    'default-gems': [
      'aws-sdk-s3',
    ],
  },
)

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
