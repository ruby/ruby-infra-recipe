# Executed as root on the target host, streamed over ssh by `bin/bootstrap`.
# Expects `admin=<name>` to be prepended to this stream, and an
# `install_keys <<'BOOTSTRAP_KEYS' ... BOOTSTRAP_KEYS` call appended after it.
set -eu

: "${admin:?admin user is not set}"

os="$(uname -s)"
distro=unknown
if [ -r /etc/os-release ]; then
  . /etc/os-release
  distro="$ID"
fi

case "$os" in
Linux)
  case "$distro" in
  fedora|amzn|centos)
    dnf install -y which curl git rsync
    ;;
  rhel)
    dnf install -y which curl git rsync
    dnf config-manager --set-enabled "codeready-builder-for-rhel-${VERSION_ID%%.*}-rhui-rpms"
    ;;
  debian|ubuntu)
    apt-get update -q
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl git rsync
    ;;
  opensuse*|sles)
    zypper --non-interactive install which curl git rsync
    ;;
  arch)
    pacman -Sy --noconfirm --needed which curl git rsync
    ;;
  *)
    echo "bootstrap: unsupported distro '$distro'" >&2
    exit 1
    ;;
  esac
  ;;
FreeBSD)
  env ASSUME_ALWAYS_YES=yes pkg install -y sudo bash curl git rsync
  ;;
*)
  echo "bootstrap: unsupported OS '$os'" >&2
  exit 1
  ;;
esac

# Same gid mapping as recipes/setup-users.rb
shell=""
case "$distro" in
debian|ubuntu) gid=27; shell=/bin/bash ;; # sudo
opensuse*) gid=100 ;;                     # users (workaround no wheel)
arch) gid=998 ;;                          # wheel
*) gid=10 ;;                              # wheel
esac
if [ "$os" = FreeBSD ]; then gid=0; fi    # wheel

if ! id "$admin" >/dev/null 2>&1; then
  if [ "$os" = FreeBSD ]; then
    pw useradd -n "$admin" -g "$gid" -m
  else
    useradd -m -g "$gid" ${shell:+-s "$shell"} "$admin"
  fi
fi

home=$(getent passwd "$admin" | cut -d: -f6)
mkdir -p "$home/.ssh"
chmod 755 "$home"
chmod 700 "$home/.ssh"

sudoers_dir=/etc/sudoers.d
if [ "$os" = FreeBSD ]; then sudoers_dir=/usr/local/etc/sudoers.d; fi
mkdir -p "$sudoers_dir"
printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$admin" > "$sudoers_dir/50-$admin"
chmod 440 "$sudoers_dir/50-$admin"
visudo -cf "$sudoers_dir/50-$admin"

install_keys() {
  cat > "$home/.ssh/authorized_keys"
  chmod 600 "$home/.ssh/authorized_keys"
  chown -R "$admin" "$home/.ssh"
  echo "bootstrap: completed for ${admin}@$(hostname)"
}
