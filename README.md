# rubyci-recipe

## Usage

### Prepare environment for hocho apply
(some of them are to be automated using hocho)

1. Add the ssh configuration to `~/.ssh/config` for your machine as follows. The `Host <ip address>` is used as an argument of the `hocho apply` later.

    ```
    Host debian.rubyci.org
      User=<user>
      IdentityFile <path to key>
    ```

2. Install `curl` and `rsync` commands in the target VM server.
3. Add the `NOPASSWD` option to `/etc/sudoers` for your logined user in the target VM server.

#### OpenBSD
(to be automated using hocho)

```bash
doas pkg_add rsync
doas pkg_add bash
doas pkg_add sudo # then add NOPASSWD to /etc/sudoers
```

#### Funtoo

```bash
# Try adding `package 'eix'` before all other `package` next time
sudo emerge eix
sudo eix-update # to be automated too
```

### Run hocho

The specified domain is equivalent with the `Host <ip address>` in the `~/.ssh/config`.

```bash
# dry-run
bin/hocho apply -n debian.rubyci.org

# apply
bin/hocho apply debian.rubyci.org
```

### All chkbuild

```bash
# dry-run
for i in debian10 funtoo amazon amazon2 opensuseleap arch icc freebsd12 fedora31 fedora32 centos7 debian8 debian9 debian openbsd ubuntu1804 ubuntu2004 ubuntu riscv graviton2 ppc64le; do bundle exec hocho apply -n "${i}.rubyci.org"; done

# apply
for i in debian10 funtoo amazon amazon2 opensuseleap arch icc freebsd12 fedora31 fedora32 centos7 debian8 debian9 debian openbsd ubuntu1804 ubuntu2004 ubuntu riscv graviton2 ppc64le; do bundle exec hocho apply "${i}.rubyci.org"; done
```

## TODO for chkbuild user

* Added rbenv PATH to `.bash_profile`
* Added crontab with aws credentials.

## License

[Ruby License](https://www.ruby-lang.org/en/about/license.txt)
