# Cross-compilation toolchains for the crossruby host. Included from
# default.rb only when attributes.chkbuild.command is start-cross-rubyci,
# i.e. the host builds cross targets instead of plain ruby branches.
# The host is Ubuntu; no other platform is supported here.

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

node.reverse_merge!(
  crossruby: {
    # Also referenced from attributes.chkbuild.command_env in hosts.yml
    # (WASI_SDK_PATH and the android NDK PATH prefix); keep them in sync.
    wasi_sdk_version: '25.0',
    android_ndk_version: 'r28b',
  },
)

opt = '/home/chkbuild/opt'

directory opt do
  owner 'chkbuild'
  mode '755'
end

wasi_sdk_version = node[:crossruby][:wasi_sdk_version]
wasi_sdk_dir = "wasi-sdk-#{wasi_sdk_version}-x86_64-linux"
wasi_sdk_tag = "wasi-sdk-#{wasi_sdk_version.split('.').first}"
wasi_sdk_url = "https://github.com/WebAssembly/wasi-sdk/releases/download/#{wasi_sdk_tag}/#{wasi_sdk_dir}.tar.gz"

# The trailing test fails the run when the tarball was truncated; a later
# run then re-extracts over the partial tree.
execute "install #{wasi_sdk_dir}" do
  command "cd #{opt} && curl -fsSL #{wasi_sdk_url} | tar -xz && test -x #{wasi_sdk_dir}/bin/clang"
  user 'chkbuild'
  not_if "test -x #{opt}/#{wasi_sdk_dir}/bin/clang"
end

android_ndk_version = node[:crossruby][:android_ndk_version]
android_ndk_dir = "android-ndk-#{android_ndk_version}"
android_ndk_url = "https://dl.google.com/android/repository/#{android_ndk_dir}-linux.zip"
android_ndk_clang = "#{android_ndk_dir}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android30-clang"

execute "install #{android_ndk_dir}" do
  command "cd #{opt} && curl -fsSLo #{android_ndk_dir}-linux.zip #{android_ndk_url} && unzip -oq #{android_ndk_dir}-linux.zip && rm #{android_ndk_dir}-linux.zip && test -x #{android_ndk_clang}"
  user 'chkbuild'
  not_if "test -x #{opt}/#{android_ndk_clang}"
end
