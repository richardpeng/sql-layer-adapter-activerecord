# How to Run Tests

## Unit Tests

```
<start FoundationDB SQL Layer>
git clone git@github.com:FoundationDB/activerecord-fdbsql-adapter.git
bundle install
bundle exec rake test:unit
```

## ActiveRecord Tests

### Patch Note

You may notice a patch being applied in the section below. The
ActiveRecord test suite attempts to create foreign keys by default.
These are unsupported by the FoundationDB SQL Layer. These keys are
already skipped when running against SQLite so the patch adds the
FDBSQL adapter to the skip list as well. View the patch file (e.g
`cat activerecord_test_schema.patch` ) to see the exact location
and contents of change.

```
<start FoundationDB SQL Layer>
git clone git@github.com:FoundationDB/activerecord-fdbsql-adapter.git
bundle install
cd $(bundle show activerecord) ; git apply "${OLDPWD}/activerecord_test_schema.patch" ; cd -
bundle exec rake rebuild_databases ARCONFIG="${PWD}/test/config.yml"
bundle exec rake test:activerecord ARCONFIG="${PWD}/test/config.yml"
```

The tests of this adapter depend on the existence of the Rails source
code which is automatically cloned for you at the latest version of
rails with `bundler`.

However you can clone Rails from git://github.com/rails/rails.git and
set the `RAILS_SOURCE` environment variable so bundler will use another
local path instead.

## Test Databases

The default names for the test databases are `activerecord_unittest` and
`activerecord_unittest2`. 

## Current Expected Failures

These are fail due to features unsupported by the FoundationDB SQL Layer.

* test_disable_referential_integrity
* test_foreign_key_violations_are_translated_to_specific_exception
