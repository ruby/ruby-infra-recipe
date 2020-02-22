hostname = run_command('hostname').stdout.chomp

WHEEL_GID = {
  "chkbuild004.hsbt.org" => 27, # sudo
}.fetch(hostname, 10)

%w[
hsbt
mame
k0kubun
nobu
].each do |u|
  user u do
    action :create
  end

  user u do
    gid WHEEL_GID
  end

  directory "/home/#{u}" do
    mode  "755"
    owner u
  end

  directory "/home/#{u}/.ssh" do
    mode  "700"
    owner u
  end

  remote_file "/home/#{u}/.ssh/authorized_keys" do
    source "keys/#{u}.keys"
    mode  "600"
    owner u
  end
end

user "chkbuild"
directory "/home/chkbuild" do
  mode  "755"
  owner "chkbuild"
end

node.reverse_merge!(
  rbenv: {
    user: 'chkbuild',
    global: '2.5.7',
    versions: %w[
      2.5.7
    ],
  }
)

include_recipe "rbenv::user"
