# ruby-infra-recipe

## Usage

### Prepare environment for hocho apply

After launching a VM and assigning the Elastic IP (DNS records are managed under `dns/`), bootstrap the host with the cloud image's default user:

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
(to be automated using hocho)

```bash
doas pkg_add rsync
doas pkg_add bash
doas pkg_add sudo # then add NOPASSWD to /etc/sudoers
```

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

```bash
CHKBUILD_AWS_ACCESS_KEY_ID=... CHKBUILD_AWS_SECRET_ACCESS_KEY=... bin/hocho apply fedora44-arm.rubyci.org
```

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

## License

[Ruby License](https://www.ruby-lang.org/en/about/license.txt)
