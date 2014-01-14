## Running Tests

### Unit Tests

1. Start FoundationDB SQL Layer
2. `bundle install`
3. `bundle exec rake test:unit`


### ActiveRecord Tests

1. Start FoundationDB SQL Layer
2. `bundle install`
3. `$(bundle exec rake test:patch_cmd)`
    - Remove the `$(` and `)` to inspect the command before executing
4. `bundle exec rake test:active_record ARCONFIG=test/config.yml`


#### Patch Note

The patch applied in step 2 above adjusts tests with adapter specific
knowledge or skips tests exercising incompatible behavior. View the
referenced patch file directly for more details as each change is
commented.


### Rails Source

The tests of this adapter depend on the existence of the Rails source
code. The latest supported version is automatically cloned when `bundle install`
is invoked. Alternatively, you can set `RAILS_VERSION` to the desired
version or `RAILS_SOURCE` to a directory that already contains the source.


### Test Databases

The default names for the test databases are `activerecord_unittest` and
`activerecord_unittest2`. 


### Expected Failures

There are no expected failures when the test patch is applied. Please
report *any* issues encoutnered.

