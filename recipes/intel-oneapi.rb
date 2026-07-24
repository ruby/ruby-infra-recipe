# Intel oneAPI toolkit for icc.rubyci.org. chkbuild builds ruby with icx
# (see attributes.chkbuild in hosts.yml: RUBYCI_NICKNAME=icc-x64 plus the
# PATH/LD_LIBRARY_PATH pointing into /opt/intel/oneapi). The compiler comes
# from Intel's apt repository, not Ubuntu; icx/icpx and their runtime
# (libimf, libsvml, ...) come from intel-oneapi-compiler-dpcpp-cpp, pulled
# in by intel-basekit. The /opt/intel/oneapi/compiler/latest symlink
# referenced by the crontab is maintained by the packages themselves.

keyring = '/usr/share/keyrings/oneapi-archive-keyring.gpg'

package 'gnupg'

execute 'download Intel oneAPI apt keyring' do
  command "curl -fsSL https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor -o #{keyring}"
  not_if "test -s #{keyring}"
end

file '/etc/apt/sources.list.d/oneAPI.list' do
  owner 'root'
  mode '644'
  content "deb [signed-by=#{keyring}] https://apt.repos.intel.com/oneapi all main\n"
end

# Refresh the package index only while the Intel repo is still unknown to
# apt; regular index updates are handled by bin/os-update.
execute 'apt-get update' do
  not_if 'apt-cache policy | grep -q apt.repos.intel.com'
end

package 'intel-basekit'
