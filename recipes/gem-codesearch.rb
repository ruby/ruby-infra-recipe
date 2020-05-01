include_recipe "setup-users"

merged_key = Dir.glob(File.expand_path("../keys/*.keys", __FILE__)).map do |key|
  File.read(key)
end.join

file "/home/ubuntu/.ssh/authorized_keys" do
  content merged_key
  mode  '600'
  owner 'ubuntu'
end
