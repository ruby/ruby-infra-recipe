# rubyci-recipe

## Usage

```bash
# dry-run
bundle exec hocho apply -n chkbuild004.hsbt.org

# apply
bundle exec hocho apply chkbuild004.hsbt.org
```

### OpenCSW [experimental]

```bash
# dry-run
bundle exec hocho apply --config=hocho-opencsw.yml -n login.opencsw.org

# apply
bundle exec hocho apply --config=hocho-opencsw.yml login.opencsw.org
```
