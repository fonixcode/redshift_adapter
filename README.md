# RedshiftAdapter

ActiveRecord adapter for Amazon Redshift database. The gem overrides a minimal amount of code in the postgres adapter that ships with ActiveRecord to work. We only use this adapter for querying redshift so it is possible that inserting/updating is completely broken.

Here is a list of things that are broken in redshift that we work around:

    =# show client_min_messages;
    ERROR:  must be superuser to examine "client_min_messages"

    =# set time zone utc;
    ERROR:  SET TIME ZONE is not supported

    =# SET standard_conforming_strings = on;
    ERROR:  unrecognized configuration parameter "standard_conforming_strings"

This functions are overriden to do nothing. The main thing I'm worried about is `standard_conforming_strings`. Not being able to set this value may have introduced SQL injection somewhere. I'm fairly confident that normal strings will not generate SQL injection. However, other exotic features like arrays/byte data/etc might be problematic. 

    Model.connection.execute("select " + Model.connection.quote("\\"))[0]
    => {"?column?"=>"\\"}

    Model.connection.execute("select " + Model.connection.quote("\n"))[0]
    => {"?column?"=>"\n"}

    Model.where("column" => "\\").limit(1)

    Model.connection.execute("select " + Model.connection.quote("\\n"))[0]
    => {"?column?"=>"\\n"}


We also work around an 8.2 compatability problem in ActiveRecord 4.2 which has been fixed in the latest ActiveRecord:

https://github.com/rails/rails/commit/c6f8af367ec404642b8b5bd0994b8e083f60984b

Also be aware that we haven't run the specs in postgresql AR against this version nor do we have any specs. This is a YOLO redshift adapter.

The main advantage of this adapter over its competitors is that it is usually easy to follow AR security updates and fixes. Usually you just update the AR gem and everything works fine because there is almost no code that this Gem overrides/copies from AR.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'redshift_adapter'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install redshift_adapter

## Usage

Add the following to database.yml

    my_redshift_db:
      adapter: redshift
      host: name.unique.eu-west-1.redshift.amazonaws.co
      database: dbname
      port: 5439
      username: username
      password: password


## Contributing

1. Fork it ( https://github.com/[my-github-username]/redshift_adapter/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
