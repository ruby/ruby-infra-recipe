%w[
  hsbt
  mame
  k0kubun
  nobu
].each do |u|
  user u do
    case node[:platform]
    when 'debian', 'ubuntu'
      gid 27 # sudo
    else
      gid 10 # wheel
    end
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
