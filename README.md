# rubyci-recipe

## Usage

```bash
# dry-run
bundle exec hocho apply -n chkbuild004.hsbt.org

# apply
bundle exec hocho apply chkbuild004.hsbt.org
```

### All chkbuild

```bash
# dry-run
for i in 004 006 008 011 012; do bundle exec hocho apply -n "chkbuild${i}.hsbt.org"; done

# apply
for i in 004 006 008 011 012; do bundle exec hocho apply "chkbuild${i}.hsbt.org"; done
```

### OpenCSW [experimental]

```bash
# dry-run
bundle exec hocho apply --config=hocho-opencsw.yml -n login.opencsw.org

# apply
bundle exec hocho apply --config=hocho-opencsw.yml login.opencsw.org
```
