merged_key = Dir.glob(File.expand_path("keys", __dir__) + "/*").map do|key|
  File.read(key)
end.join

remote_file "/home/ubuntu/.ssh/authorized_keys" do
  source merged_key
  mode  '600'
  owner 'ubuntu'
end
