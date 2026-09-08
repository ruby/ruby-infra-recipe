# ruby-infra-recipe

## Usage

### Launch

`bin/launch` creates a host's EC2 instance through the EC2 API, so a new host needs no web console. The security group (`chkbuild`), instance profile (`chkbuild-uploader`), IMDSv2 requirement and gp3 root volume are the same for every host and are fixed in the script, which leaves the AMI id and the instance type as arguments. The subnet defaults to a default-for-az subnet of the security group's VPC, choosing an availability zone that offers the requested instance type, because the zones do not all offer the same ones. As with `bin/reboot` the region is fixed to `ap-northeast-1` and the AWS CLI is expected to be configured with credentials for the account holding the instances.

```bash
# resolve the AMI, subnet and Name tag, then dry-run the API call
bin/launch -n fedora45.rubyci.org ami-0123456789abcdef0 c5a.large

# launch, taking one of the idle Elastic IPs
bin/launch --eip 52.69.117.212 fedora45.rubyci.org ami-0123456789abcdef0 c5a.large
```

`--eip new` allocates a new Elastic IP and `--eip <address|allocation id>` takes an existing unassociated one. Either way a `*.rubyci.org` host gets its A record written into `dns/rubyci.org/dnsconfig.js`, and committing that is what applies the zone. Without `--eip` the instance keeps the address its subnet assigns, which is lost on the next stop. The Name tag is `rubyci-<label>`; pass `--name` where that does not hold, as with `riscv.rubyci.org` running on `rubyci-riscv64`.

### Elastic IP swap

Rotating an EOL host out reuses its Elastic IP, which leaves the DNS record alone. Launch the replacement with `bin/launch` and no `--eip`, bootstrap and apply it on the temporary address its subnet assigns, and hand it the host name with `bin/eip-swap` only once it works. The old instance keeps running and loses its public address, so stop or terminate it after the replacement is known good.

```bash
# report which instance holds the address today, and dry-run the API call
bin/eip-swap -n debian11.rubyci.org i-0123456789abcdef0

# swap
bin/eip-swap debian11.rubyci.org i-0123456789abcdef0
```

The replacement answers on a different host key under the same name, so `ssh-keygen -R <host>` is needed before the next `bin/hocho apply`. Both are printed as next steps.

### Register with rubyci.org

rubyci.org does not discover servers from the S3 bucket, so a host stays invisible on the page until a `Server` row exists for it, and that row is the one step of adding a host that lives outside this repository. `bin/rubyci-server` posts it to the `servers` API, deriving the log uri from the nickname the host's crontab reports under. The `root` basic-auth password is read from the app's own `ROOT_PASSWORD` config var rather than copied into a second place, which is why posting goes through the heroku CLI.

```bash
# read the public server list and print what would be posted; no credentials needed
bin/rubyci-server -n "Fedora 45 x86_64" fedora45

# rehearse against the staging app
op run --env-file ~/.config/credentials/heroku.env -- bin/rubyci-server --app staging-rubyci "Fedora 45 x86_64" fedora45

# register
op run --env-file ~/.config/credentials/heroku.env -- bin/rubyci-server "Fedora 45 x86_64" fedora45
```

The page is sorted by `ordinal`, a float. The default appends the host to the bottom, from where the servers page moves it up; `--ordinal` between two neighbours puts it next to its family straight away. `--eol` records the end of life shown for hosts that are on their way out.

### Prepare environment for hocho apply

After the instance exists and its DNS record is live (`bin/launch` does both for EC2 hosts; records are managed under `dns/rubyci.org/`, see `dns/README.md`), bootstrap the host with the cloud image's default user:

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

Once logged into the Ubuntu VM, install packages, setup swap (to reduce the odds
of the OOM killer killing the VM), create the disk image for the OpenBSD VM, and
download the OpenBSD ISO (this uses 7.9, but the latest available version should
be used):

```sh
sudo apt update
sudo apt install -y qemu-system-x86 qemu-utils cpu-checker

sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
sudo swapon --show

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
  -m 2560 \
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

After you see:

```
The operating system has halted.
Please press any key to reboot.
```

Then do `Ctrl+A`, then `X` to have qemu exit.

Setup a script to start the OpenBSD VM, forwarding port 2222 on the Ubuntu VM
to port 22 on the OpenBSD:

```sh
sudo tee /usr/local/bin/openbsd-vm.sh >/dev/null <<'EOF'
#!/bin/bash
set -euo pipefail

exec qemu-system-x86_64 \
  -m 2560 \
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

Run `sudo systemctl status openbsd-vm` to ensure it is running, and 
`sudo journalctl -u openbsd-vm | tail` to see the boot information from qemu.
It should include something like
`OpenBSD/amd64 (rubyci-openbsd.my.domain) (tty00)` near the end once it
finishes booting.

Try connecting via `ssh -p 2222 openbsd.rubyci.org`. It should
forward to the OpenBSD VM. Use the password you set during setup
for the initial SSH connection. Then copy over your SSH public
keys to `.ssh/authorized_keys` so you can connect via public
keys.

The user you created during setup will be in the `wheel` group,
but `sudo` isn't installed at this point, and `doas` (OpenBSD's
`sudo`-like) isn't enabled. Run `su` and use your password (not
the root password), which will open a root shell. Enable `doas`:

```sh
echo permit nopass keepenv :wheel > /etc/doas.conf
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

To allow `hocho` to work, add the following configuration to
`~/.ssh/config`, so that `hocho` will connect to the OpenBSD VM and
not the Ubuntu VM:

```
Host openbsd.rubyci.org
HostName openbsd.rubyci.org
Port 2222
```

If the OpenBSD VM is not responsive, run `sudo systemctl status openbsd-vm`
to stop the VM. Then connect manually using serial console:

```sh
sudo qemu-system-x86_64 \
  -m 2560 \
  -smp 2 \
  -drive file=/var/lib/vms/openbsd.qcow2,if=virtio,format=qcow2 \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
  -nographic
```

Let it boot normally. If it won't boot, and you get something like:

```
/dev/sd0a (f1765eb029d7742d.a): UNEXPECTED INCONSISTENCY; RUN fsck_ffs MANUALLY.
Automatic file system check failed; help!
fd0 at fdc0 drive 1: density unknown
Enter pathname of shell or RETURN for sh: 
```

Then hit `Enter`, and then `fsck -y`. Hopefully that will fix the issue
and at the end of the output you will see:

```
***** FILE SYSTEM WAS MODIFIED *****
```

If so, type `exit` or `Ctrl+D`, and the system should continue booting.
If it cannot complete booting, rebuild it from scratch using the instructions
in this section.

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
