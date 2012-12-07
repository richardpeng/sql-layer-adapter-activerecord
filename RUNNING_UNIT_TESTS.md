# How to Run Tests

In a nutshell:

```
git clone git@github.com:akiban/activerecord-akiban-adapter.git
bundle install
AR_PATH=$(bundle show activerecord)
pushd $AR_PATH && git apply $OLDPWD/rails.patch && popd
bundle exec rake rebuild_databases ARCONFIG="$PWD/test/config.yml"
bundle exec rake test ARCONFIG="$PWD/test/config.yml"
```

The tests of this adapter depend on the existence of the Rails source
code which is automatically cloned for you at the latest version of
rails with `bundler`.

However you can clone Rails from git://github.com/rails/rails.git and
set the `RAILS_SOURCE` environment variable so bundler will use another
local path instead.

## Rails Patch

You will notice that in order to run the unit tests a patch is applied
to the rails source code that `bundler` installs. This patch is quite
simple and its sole purpose is to make sure that tests which are not
applicable to Akiban are skipped. The current contents of the patch are:

```
diff --git a/activerecord/test/schema/schema.rb b/activerecord/test/schema/schema.rb
index 8a3dfbb..3dfa18c 100644
--- a/activerecord/test/schema/schema.rb
+++ b/activerecord/test/schema/schema.rb
@@ -746,7 +746,7 @@ ActiveRecord::Schema.define do
     t.string 'a$b'
   end
 
-  except 'SQLite' do
+  except ['SQLite', 'Akiban'] do
     # fk_test_has_fk should be before fk_test_has_pk
     create_table :fk_test_has_fk, :force => true do |t|
       t.integer :fk_id, :null => false
```

## Test Databases

The default names for the test databases are `activerecord_unittest` and
`activerecord_unittest2`. 

## Current Expected Failures

The majority of these fail because Akiban does not support a certain feature
right now.

* test_disable_referential_integrity
* test_foreign_key_violations_are_translated_to_specific_exception
