# ruby-infra-recipe

## Usage

### Prepare environment for hocho apply

After launching a VM and assigning the Elastic IP (DNS records are managed under `dns/rubyci.org/`, see `dns/README.md`), bootstrap the host with the cloud image's default user:

```bash
bin/bootstrap -i ~/.ssh/aws-keypair.pem fedora@fedora44-arm.rubyci.org
```

The `-i` key is the AWS keypair injected at instance launch. Omit it if the keypair is available via your ssh agent.

This streams `bin/bootstrap-remote.sh` over ssh and automates the previous manual steps:

- installs `which`, `curl`, `git` and `rsync`
- creates your admin user with `recipes/keys/<you>.keys` and NOPASSWD sudo
- enables CodeReady Linux Builder repository on RHEL
- installs `sudo` and `bash` on FreeBSD

No `~/.ssh/config` entry is needed. After bootstrap, `bin/hocho apply` connects as your own user. If the Elastic IP was reused from another host, remove the stale host key with `ssh-keygen -R <host>` first.

Supported platforms: Fedora, RHEL, CentOS, Amazon Linux, Debian, Ubuntu, openSUSE, Arch and FreeBSD. Use the manual steps below for the others.

### OpenBSD

RubyCI for OpenBSD is done by Running OpenBSD in a qemu VM inside a Ubuntu VM.
This describes the setup process.

Once logged into the Ubuntu VM, install packages, create the disk image for the
OpenBSD VM, and download the OpenBSD ISO (this uses 7.9, but the latest available
version should be used):

```sh
sudo apt update
sudo apt install -y qemu-system-x86 qemu-utils cpu-checker

sudo mkdir -p /var/lib/vms
sudo qemu-img create -f qcow2 /var/lib/vms/openbsd.qcow2 30G

curl -o install79.iso https://cdn.openbsd.org/pub/OpenBSD/7.9/amd64/install79.iso
```

Next we'll install OpenBSD inside qemu. When the following command runs,
start typing `set tty com0` at the `boot>` prompt (you have about 5 seconds to
start typing). After submitting that, at the next `boot>` prompt, type `boot`
to start the OpenBSD installer boot.

```sh
sudo qemu-system-x86_64 \
  -m 3072 \
  -smp 2 \
  -drive file=/var/lib/vms/openbsd.qcow2,if=virtio,format=qcow2 \
  -cdrom install79.iso \
  -boot d \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
  -nographic
```

Important information during OpenBSD installation. If an answer
isn't listed here, use the default:

* System hostname: `rubyci-openbsd`
* Password: randomly generate a secure one and store it
* Do you expect to run the X Window System? `no`
* Which speed should com0 use? `115200`
* Setup a user? Enter a username for yourself, then a different secure password
* Disk setup: `c` for custom, then follow these prompts for 1G swap and rest a
  single partition:
  ```
  sd0> a b
  offset: [64]
  size: [62914496] 1g
  FS type: [swap]
  sd0*> a a
  offset: [2104515]
  size: [60810045]
  FS type: [4.2BSD]
  mount point: [none] /
  sd0*> q
  Write new label?: [y]
  ```
* Location of sets? `cd0`
* Directory does not contain SHA256.sig. Continue without verification? `yes`
* Exit to (S)hell, (H)alt or (R)eboot? `h`

Then do `Ctrl+A`, then `X` to have qemu exit.

Setup a script to start the OpenBSD VM, forwaring port 2222 on the Ubuntu VM
to port 22 on the OpenBSD:

```sh
sudo tee /usr/local/bin/openbsd-vm.sh >/dev/null <<'EOF'
#!/bin/bash
set -euo pipefail

exec qemu-system-x86_64 \
  -m 3072 \
  -smp 2 \
  -drive file=/var/lib/vms/openbsd.qcow2,if=virtio,format=qcow2 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -nographic
EOF
sudo chmod +x /usr/local/bin/openbsd-vm.sh
```

Setup systemd to start the OpenBSD VM and autostart it on Ubuntu boot:

```sh
sudo tee /etc/systemd/system/openbsd-vm.service >/dev/null <<'EOF'
[Unit]
Description=OpenBSD QEMU VM
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/openbsd-vm.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now openbsd-vm.service
```

Run `systemctl status openbsd-vm` to ensure it is running, and 
`journalctl -u openbsd-vm | tail` to see the boot information from qemu.
It should include something like
`OpenBSD/amd64 (rubyci-openbsd.my.domain) (tty00)` near the end.

Try connecting via `ssh -P 2222 openbsd.rubyci.org`. It should
forward to the OpenBSD VM. Use the password you set during setup
for the initial SSH connection. Then copy over your SSH public
keys to `.ssh/authorized_keys` so you can connect via public
keys.

The user you created during setup will be in the `wheel` group,
but `sudo` isn't installed at this point, and `doas` (OpenBSD's
`sudo`-like) isn't enabled. Run `su` and use your password (not
the root password), which will open a root shell. Enable `doas`:

```sh
echo permit nopass keepenv :wheel > /etc/doas
```

Then exit the root shell. 

Install the necessary packages needed for CI:

```sh
doas pkg_add rsync-- bash sudo-- git
```

Then configure `sudo`

```sh
doas vi /etc/sudoers
```

Uncomment the `# %wheel        ALL=(ALL) NOPASSWD: SETENV: ALL` line.

From this point on, you can use `sudo` or `doas`, either will work.

### Funtoo

```bash
# Try adding `package 'eix'` before all other `package` next time
sudo emerge eix
sudo eix-update # to be automated too
```

### Run hocho

The specified domain is equivalent with the `Host <ip address>` in the `~/.ssh/config`.

```bash
# check if you can login
bash -cx "ssh debian.rubyci.org echo OK"

# dry-run
bin/hocho apply -n debian.rubyci.org

# apply
bin/hocho apply debian.rubyci.org
```

### chkbuild crontab

The chkbuild user's crontab is installed only when AWS credentials are given via environment variables at apply time. Without them the crontab is left untouched. `RUBYCI_NICKNAME` is derived from the host name (e.g. `fedora44-arm`).

The cron interval defaults to every 3 hours and can be overridden per host with `attributes.chkbuild.schedule` in `hosts.yml`. The interval is sized from the measured duration of one full chkbuild cycle (all branches) on rubyci.org plus ~15 minutes of headroom, since chkbuild aborts when the previous run still holds its lock.

The cron command runs `start-rubyci` by default and can be overridden per host with `attributes.chkbuild.command` (e.g. `start-cross-rubyci` on crossruby). Extra crontab environment lines can be added per host with the `attributes.chkbuild.env` mapping (e.g. `LC_ALL: C` and `DFLTCC: "0"` on s390x). Environment that needs shell expansion goes in the `attributes.chkbuild.command_env` mapping instead, which is prepended inline to the build command (e.g. the android NDK `PATH` prefix and `WASI_SDK_PATH` on crossruby); cron takes crontab environment lines literally and would not expand `$PATH`.

```bash
CHKBUILD_AWS_ACCESS_KEY_ID=... CHKBUILD_AWS_SECRET_ACCESS_KEY=... bin/hocho apply fedora44-arm.rubyci.org
```

### Intel oneAPI (icc.rubyci.org)

`recipes/intel-oneapi.rb` sets up Intel's apt repository and installs `intel-basekit`, which provides the `icx` compiler chkbuild uses on this host. The crontab environment that switches the build to icx (`PATH`, `LD_LIBRARY_PATH`) is defined in `attributes.chkbuild.env` in `hosts.yml`.

### crossruby toolchains

When `attributes.chkbuild.command` is `start-cross-rubyci`, `recipes/crossruby.rb` installs the cross toolchains on top of the common setup: the Ubuntu cross gcc packages for the linux/mingw targets, emscripten, and the WASI SDK and Android NDK under `/home/chkbuild/opt`. The WASI SDK and NDK versions are resolved to the latest stable GitHub release at every apply, and the version-independent symlinks `/home/chkbuild/opt/wasi-sdk` and `/home/chkbuild/opt/android-ndk` are pointed at them, so the crontab paths in `attributes.chkbuild.command_env` never change. Superseded toolchain versions are removed, except directories still referenced by the installed crontab (an apply without AWS credentials leaves the crontab untouched, and its toolchains must survive until the next apply with credentials).

### macOS hosts (fuji, ringo)

The macOS hosts are addressed by the ssh aliases `fuji` and `ringo` from `~/.ssh/config`, not by rubyci.org names. Everything runs as the pre-existing user named by `attributes.chkbuild.user` in `hosts.yml`, currently the hsbt login user. `recipes/macos.rb` manages the MacPorts build dependencies, rbenv with aws-sdk-s3 as a default gem, the chkbuild checkouts and the crontab. OS provisioning, Xcode Command Line Tools and the MacPorts installer itself are out of scope. sudo must be passwordless, via a drop-in in `/private/etc/sudoers.d` (the file name must not contain a period). With that in place `bin/hocho apply fuji` works like any other host.

Keep the checkouts out of `~/Desktop`, `~/Documents` and `~/Downloads`. macOS TCC denies a cron-launched rbenv ruby access to those directories, and because the crontab sets `MAILTO=""` the build dies without a trace: no build directory, no line in `tmp/build/.lock`, no mail. `sudo log show --start "<cron minute>" --info` on the host shows the `sandboxd rejected approval request from ruby for kTCCServiceSystemPolicyDocumentsFolder` denial. Running the same command by hand over ssh succeeds, because sshd holds Full Disk Access and the child inherits it.

### All chkbuild

`bin/all-hosts` runs a command for every host in `hosts.yml` in parallel, appending the host name as the last argument. Full per-host output goes to `$TMPDIR/all-hosts-<timestamp>/<host>.log` and a summary is printed at the end. Use `-j N` to limit concurrency.

```bash
# check if you can login (the host name is appended as the last argument)
bin/all-hosts sh -c 'ssh -o BatchMode=yes "$0" echo OK'

# dry-run
bin/all-hosts bin/hocho apply -n

# apply
bin/all-hosts bin/hocho apply
```

### OS updates

`bin/os-update` runs OS package updates on a single host over ssh. It detects the platform on the host and picks the right command (dnf, yum, apt, zypper, pacman, pkg + freebsd-update). OpenBSD is updated by its own maintainer and is always skipped. Reboots are never performed; the final output line reports whether one is needed.

```bash
# check for pending updates only
bin/os-update -n fedora43.rubyci.org

# apply updates
bin/os-update fedora43.rubyci.org

# all hosts
bin/all-hosts bin/os-update
```

### Reboots

`bin/reboot` reboots a single EC2 host through the EC2 API, so a host whose ssh has wedged can still be recycled from the command line. RebootInstances asks the guest OS to reboot and hard-resets only if it does not answer within a few minutes, so it suits a healthy host too. `hosts.yml` carries no instance id, so the host name is resolved through DNS and the instance is looked up by that address. That is exact where the `Name` tag is not: `riscv.rubyci.org` runs on `rubyci-riscv64` and a stopped `rubyci-riscv` still exists. The non-EC2 hosts are skipped. The region is fixed to `ap-northeast-1`; the AWS CLI is expected to be configured with credentials for the account holding the instances.

```bash
# resolve the instance and dry-run the API call
bin/reboot -n fedora43.rubyci.org

# reboot
bin/reboot fedora43.rubyci.org

# all hosts
bin/all-hosts bin/reboot
```

### gem-codesearch MCP server (gem-codesearch.dev.ruby-lang.org)

`recipes/gem-codesearch.rb` runs the MCP server from [akr/gem-codesearch](https://github.com/akr/gem-codesearch) as the systemd unit `gem-codesearch-mcp` (puma on localhost:9292) behind nginx, which terminates TLS with a certbot certificate obtained manually on the host. mame's services on the same host (`mame.dev.ruby-lang.org`, `/etc/nginx/sites-available/ssl.conf`, systemd user units) are not managed by this repository.

The server requires a Bearer token. It is generated on the host at first apply with `openssl rand -hex 32` into `/etc/gem-codesearch/mcp-token.env` and is never stored in this repository. To read it:

```bash
ssh gem-codesearch.dev.ruby-lang.org sudo cat /etc/gem-codesearch/mcp-token.env
```

To rotate it, remove the file, re-apply, and restart the unit:

```bash
ssh gem-codesearch.dev.ruby-lang.org "sudo rm /etc/gem-codesearch/mcp-token.env" && bin/hocho apply gem-codesearch.dev.ruby-lang.org && ssh gem-codesearch.dev.ruby-lang.org sudo systemctl restart gem-codesearch-mcp
```

Client registration:

```bash
claude mcp add --transport http gem-codesearch https://gem-codesearch.dev.ruby-lang.org/ --header "Authorization: Bearer <token>"
```

## License

[Ruby License](https://www.ruby-lang.org/en/about/license.txt)
