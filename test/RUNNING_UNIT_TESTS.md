## Running Tests

### Unit Tests

```sh
<start FoundationDB SQL Layer>
git clone git@github.com:FoundationDB/sql-layer-adapter-activerecord.git
bundle install
bundle exec rake test:unit
```

### ActiveRecord Tests

```sh
<start FoundationDB SQL Layer>
git clone git@github.com:FoundationDB/sql-layer-adapter-activerecord.git
bundle install
cd $(bundle show activerecord) ; git apply "${OLDPWD}/test/activerecord_3_test_changes.patch" ; cd -
bundle exec rake test:activerecord ARCONFIG="${PWD}/test/config.yml"
```

#### Patch Note

The patch applied above adjusts tests with adapter specific knowledge or
skips tests assuming incompatible behavior. View the patch file directly
for full details as each change is commented details.


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

If the patch is applied, there are no expected failures. Please report any
encountered.

