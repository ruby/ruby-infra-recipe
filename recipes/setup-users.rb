Dir.glob(File.expand_path("../keys/*.keys", __FILE__)).sort.each do |key|
  u = File.basename(key).delete_suffix('.keys')
  user u do
    case node[:platform]
    when 'debian', 'ubuntu'
      gid 27 # sudo
      shell '/bin/bash'
    when 'freebsd', 'openbsd'
      gid 0 # wheel
    when 'opensuse'
      gid 100 # users (workaround no wheel)
    else
      gid 10 # wheel
    end
  end

  directory "/home/#{u}" do
    mode  '755'
    owner u
  end

  directory "/home/#{u}/.ssh" do
    mode  '700'
    owner u
  end

  remote_file "/home/#{u}/.ssh/authorized_keys" do
    source "keys/#{u}.keys"
    mode  '600'
    owner u
  end
end
