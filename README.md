# rubyci-recipe

## Usage

### Prepare environment for hocho apply
(some of them are to be automated using hocho)

1. Added ssh configuration to `~/.ssh/config` for your machine.
2. Install curl and rsync in target VM.
3. Added `NOPASSWD` option to `/etc/sudoers` in target VM.

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

```bash
# dry-run
bundle exec hocho apply -n debian.rubyci.org

# apply
bundle exec hocho apply debian.rubyci.org
```

### All chkbuild

```bash
# dry-run
for i in debian10 funtoo amazon amazon2 opensuseleap arch icc freebsd12 fedora31 fedora32 centos6 centos7 centos8 debian8 debian9 debian openbsd ubuntu1604 ubuntu1804 ubuntu2004 ubuntu riscv; do bundle exec hocho apply -n "${i}.rubyci.org"; done

# apply
for i in debian10 funtoo amazon amazon2 opensuseleap arch icc freebsd12 fedora31 fedora32 centos6 centos7 centos8 debian8 debian9 debian openbsd ubuntu1604 ubuntu1804 ubuntu2004 ubuntu riscv; do bundle exec hocho apply "${i}.rubyci.org"; done
```

## TODO for chkbuild user

* Added rbenv PATH to `.bash_profile`
* Added crontab with aws credentials.

## License

[Ruby License](https://www.ruby-lang.org/en/about/license.txt)
