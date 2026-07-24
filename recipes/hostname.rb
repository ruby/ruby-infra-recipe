# Set the hostname to the rubyci FQDN (e.g. fedora44-arm.rubyci.org).
# node[:fqdn] is injected by the ruby_script property provider in hocho.yml
# for *.rubyci.org hosts only, so other hosts are left untouched.
fqdn = node[:fqdn]

if fqdn && !fqdn.empty?
  case node[:platform]
  when 'freebsd'
    execute "sysrc hostname=#{fqdn} && hostname #{fqdn}" do
      not_if %Q(test "$(hostname)" = #{fqdn})
    end
  when 'openbsd'
    execute "echo #{fqdn} > /etc/myname && hostname #{fqdn}" do
      not_if %Q(test "$(hostname)" = #{fqdn})
    end
  else
    execute "hostnamectl set-hostname #{fqdn}" do
      not_if %Q(test "$(hostname)" = #{fqdn})
    end
  end
end
