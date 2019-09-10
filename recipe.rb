%w[
hsbt
mame
k0kubun
nobu
].each do |u|
  user u do
    action :create
  end

  directory "/home/#{u}" do
    mode  "755"
    owner u
  end

  directory "/home/#{u}/.ssh" do
    mode  "700"
    owner u
  end

  file "/home/#{u}/.ssh/authorized_keys" do
    mode  "600"
    owner u
    content File.read("keys/#{u}.keys")
  end
end
