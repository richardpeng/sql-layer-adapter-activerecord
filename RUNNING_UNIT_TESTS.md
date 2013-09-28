## Running Tests

### Unit Tests

```sh
<start FoundationDB SQL Layer>
git clone git@github.com:FoundationDB/activerecord-fdbsql-adapter.git
bundle install
bundle exec rake test:unit
```

### ActiveRecord Tests

```sh
<start FoundationDB SQL Layer>
git clone git@github.com:FoundationDB/activerecord-fdbsql-adapter.git
bundle install
cd $(bundle show activerecord) ; git apply "${OLDPWD}/activerecord_test_schema.patch" ; cd -
bundle exec rake rebuild_databases ARCONFIG="${PWD}/test/config.yml"
bundle exec rake test:activerecord ARCONFIG="${PWD}/test/config.yml"
```

#### Patch Note

The patch applied above skips the creation of foreign keys during
test setup as they are not supported. These keys are already skipped
when running against SQLite. The patch adds this adapter to the 
exclude list. View the patch file (e.g `cat activerecord_test_schema.patch`)
to see the exact location and contents of change.


### Rails Source

The tests of this adapter depend on the existence of the Rails source
code which is automatically cloned for you at the latest version of
rails with `bundler`.

However you can clone Rails from https://github.com/rails/rails.git and
set the `RAILS_SOURCE` environment variable to cause bundler to use 
your custom path.


### Test Databases

The default names for the test databases are `activerecord_unittest` and
`activerecord_unittest2`. 


### Expected Failures

These are fail due to features unsupported by the FoundationDB SQL Layer.

* test_disable_referential_integrity
* test_foreign_key_violations_are_translated_to_specific_exception
