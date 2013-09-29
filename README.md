## FoundationDB SQL Layer ActiveRecord Adapter

The [FoundationDB SQL Layer](https://github.com/FoundationDB/sql-layer) is a
full SQL implementation build upon the [FoundationDB](https://foundationdb.com)’s
storage substrate. It provides the same high performance, multi-node scalability,
fault-tolerance, and true multi-key ACID transactions.

This project provides connection adapter integration for ActiveRecord.


### Supported ActiveRecord Versions

This project currently supports the v3.2 series.

Support for v4.0, the current stable release, is underway but not yet complete.


### Quick Start

1. Add to `Gemfile`
2. Install
3. Update configuration
4. Setup database

For a concrete example, we can easily use this adapter when following the
[Getting Started with Rails](http://guides.rubyonrails.org/v3.2.14/getting_started.html)
guide.

Follow the guide up to Step 3.3 and the perform the steps mentioned above:

1. Add the following line to `Gemfile`:
    - `gem 'activerecord-fdbsql-adapter', github: 'FoundationDB/sql-layer-adapter-activerecord'`
2. Install the new gem
    - `$ bundle install`
3. Edit `config/database.yml` to look like:

    ```yaml
    development:
      adapter: fdbsql
      database: blog_dev
      host: localhost
      port: 15432
      username: test
      password:
   ```
4. Setup the database
    - `$ rake db:create`
6. Continue with the guide at Step 4

### Contributing

1. Fork
2. Branch
3. Commit
4. Pull Request

If you would like to contribute a feature or fix, thanks! Please make
sure any changes come with new tests to ensure acceptance. Please read
the `RUNNING_UNIT_TESTS.md` file for more details.

### Contact

* GitHub: http://github.com/FoundationDB/sql-layer-adapter-activerecord
* Community: http://community.foundationdb.com
* IRC: #FoundationDB on irc.freenode.net

### License

The MIT License (MIT)  
Copyright (c) 2012-13 FoundationDB, LLC  
It is free software and may be redistributed under the terms specified
in the LICENSE file.

