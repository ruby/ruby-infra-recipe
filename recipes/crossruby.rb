# Cross-compilation toolchains for the crossruby host. Included from
# default.rb only when attributes.chkbuild.command is start-cross-rubyci,
# i.e. the host builds cross targets instead of plain ruby branches.
# The host is Ubuntu; no other platform is supported here.

# wasm-opt peaks at ~3.4 GB anon RSS while the host has 3.8 GB and no swap.
# The resulting global OOM thrash has repeatedly stalled systemd-networkd's
# DHCPv4 renewal, dropping ens5 (and ssh) until a reboot.
execute 'create /swapfile' do
  command 'fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile'
  not_if 'test -e /swapfile'
end

execute 'enable /swapfile' do
  command 'swapon /swapfile'
  not_if 'swapon --show=NAME --noheadings | grep -qx /swapfile'
end

execute 'register /swapfile in /etc/fstab' do
  command "echo '/swapfile none swap sw 0 0' >> /etc/fstab"
  not_if 'grep -q "^/swapfile " /etc/fstab'
end

# start-cross-rubyci probes each cross compiler with Util.search_command and
# skips targets whose compiler is missing, so this list is what makes the
# linux/mingw targets actually build. mips (big-endian) and s390 are also
# defined there but Ubuntu ships no compiler for them.
%w[
  gcc-mingw-w64-i686
  gcc-mingw-w64-x86-64
  gcc-arm-linux-gnueabi
  gcc-mipsel-linux-gnu
  gcc-powerpc-linux-gnu
  gcc-sparc64-linux-gnu
  gcc-aarch64-linux-gnu
  gcc-hppa-linux-gnu
  gcc-m68k-linux-gnu
].each do |pkg|
  package pkg
end

# wasm32/64-emscripten targets build with Ubuntu's emcc; nodejs comes in as
# a dependency. The wasm32-wasi and android targets use the toolchains
# installed under /home/chkbuild/opt below.
package 'emscripten'

# Every build runs ./autogen.sh from a git checkout; the rbenv dependency
# recipe covers the rest of the ruby build dependencies but not these two.
package 'autoconf'
package 'bison'

package 'unzip' # to extract the android NDK zip below

opt = '/home/chkbuild/opt'

directory opt do
  owner 'chkbuild'
  mode '755'
end

# Resolve the latest stable releases at apply time so every hocho apply
# rolls the toolchains forward. The crontab in hosts.yml references the
# version-independent wasi-sdk/android-ndk symlinks below, so a version
# bump needs no crontab update. mitamae has no run_command in the recipe
# context; the backticks come from mruby-io and run on the host.
wasi_api = `curl -fsSL --max-time 30 https://api.github.com/repos/WebAssembly/wasi-sdk/releases/latest`
unless wasi_api =~ %r{"browser_download_url": *"(https://[^"]+/(wasi-sdk-[0-9.]+-x86_64-linux))\.tar\.gz"}
  raise 'cannot resolve the latest wasi-sdk release from the GitHub API'
end
wasi_sdk_url = "#{$1}.tar.gz"
wasi_sdk_dir = $2

ndk_api = `curl -fsSL --max-time 30 https://api.github.com/repos/android/ndk/releases/latest`
unless ndk_api =~ /"tag_name": *"(r[0-9]+[a-z]*)"/
  raise 'cannot resolve the latest android NDK release from the GitHub API'
end
android_ndk_dir = "android-ndk-#{$1}"
android_ndk_url = "https://dl.google.com/android/repository/#{android_ndk_dir}-linux.zip"
android_ndk_clang = "#{android_ndk_dir}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android30-clang"

# The trailing test fails the run when the download was truncated; a later
# run then re-extracts over the partial tree.
execute "install #{wasi_sdk_dir}" do
  command "cd #{opt} && curl -fsSL #{wasi_sdk_url} | tar -xz && test -x #{wasi_sdk_dir}/bin/clang"
  user 'chkbuild'
  not_if "test -x #{opt}/#{wasi_sdk_dir}/bin/clang"
end

link "#{opt}/wasi-sdk" do
  to "#{opt}/#{wasi_sdk_dir}"
  force true
end

execute "install #{android_ndk_dir}" do
  command "cd #{opt} && curl -fsSLo #{android_ndk_dir}-linux.zip #{android_ndk_url} && unzip -oq #{android_ndk_dir}-linux.zip && rm #{android_ndk_dir}-linux.zip && test -x #{android_ndk_clang}"
  user 'chkbuild'
  not_if "test -x #{opt}/#{android_ndk_clang}"
end

link "#{opt}/android-ndk" do
  to "#{opt}/#{android_ndk_dir}"
  force true
end

# Drop superseded toolchain versions and the manual download leftovers.
# A directory still referenced by the installed crontab is kept: without
# AWS credentials at apply time the crontab keeps its previous paths (see
# chkbuild-cron.rb) and the running builds must not lose their toolchain.
keep_current = %Q{[ "$d" = #{wasi_sdk_dir} ] && continue; [ "$d" = #{android_ndk_dir} ] && continue; grep -qF "opt/$d" /home/chkbuild/.crontab 2>/dev/null && continue}

execute 'remove old wasi-sdk/android-ndk versions' do
  command %Q{cd #{opt} && for d in wasi-sdk-[0-9]* android-ndk-r*; do [ -e "$d" ] || continue; #{keep_current}; rm -rf "$d"; done && rm -f /home/chkbuild/wasi-sdk-*.tar.gz}
  only_if %Q{cd #{opt} && { for d in wasi-sdk-[0-9]* android-ndk-r*; do [ -e "$d" ] || continue; #{keep_current}; echo "$d"; done; ls /home/chkbuild/wasi-sdk-*.tar.gz 2>/dev/null; } | grep -q .}
end
