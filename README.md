# ruby-infra-recipe

## Usage

### Prepare environment for hocho apply
(some of them are to be automated using hocho)

1. Add the ssh configuration to `~/.ssh/config` for your machine as follows. The `Host <ip address>` is used as an argument of the `hocho apply` later.

    ```
    Host debian.rubyci.org
      User=<user>
      IdentityFile <path to key>
    ```

2. Install `which`, `curl`, `git` and `rsync` commands in the target VM server.
3. Add the `NOPASSWD` option to `/etc/sudoers` for your logined user in the target VM server.

### RHEL

You should enable CodeReady Linux Builder repository for RHEL 9 or later.

```bash
sudo yum-config-manager --enable codeready-builder-for-rhel-$VERSION-rhui-rpms
```

or

```bash
sudo dnf config-manager --set-enabled codeready-builder-for-rhel-$VERSION-rhui-rpms
```

You can confirm these repos with the following command.

```bash
sudo yum repolist --all
```

### FreeBSD
(to be automated using hocho)

```bash
pkg install sudo # then add NOPASSWD with visudo
pkg install bash
```

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

### All chkbuild

```bash
# check if you can login
for i in $(bin/hosts); do bash -cx "ssh ${i} echo OK"; done

# dry-run
for i in $(bin/hosts); do bundle exec hocho apply -n "${i}"; done

# apply
for i in $(bin/hosts); do bundle exec hocho apply "${i}"; done
```

## License

[Ruby License](https://www.ruby-lang.org/en/about/license.txt)
