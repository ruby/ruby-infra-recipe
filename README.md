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

```bash
CHKBUILD_AWS_ACCESS_KEY_ID=... CHKBUILD_AWS_SECRET_ACCESS_KEY=... bin/hocho apply fedora44-arm.rubyci.org
```

### All chkbuild

```bash
# check if you can login
for i in $(bin/hosts); do bash -cx "ssh ${i} echo OK"; done

# dry-run
for i in $(bin/hosts); do bundle exec hocho apply -n "${i}"; done

# apply
for i in $(bin/hosts); do bundle exec hocho apply "${i}"; done
```

### OS updates

`bin/os-update` runs OS package updates on every host in `hosts.yml` in parallel over ssh. It detects the platform on each host and picks the right command (dnf, yum, apt, zypper, pacman, pkg + freebsd-update, syspatch + pkg_add). Reboots are never performed automatically; hosts that need one are reported in the summary.

```bash
# check for pending updates only
bin/os-update -n

# apply updates on all hosts
bin/os-update

# apply updates on specific hosts
bin/os-update fedora43.rubyci.org ubuntu2404.rubyci.org
```

Full per-host output is written to `$TMPDIR/os-update-<timestamp>/<host>.log`.

## License

[Ruby License](https://www.ruby-lang.org/en/about/license.txt)
