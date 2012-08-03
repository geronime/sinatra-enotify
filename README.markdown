# sinatra-enotify - Sinatra exception notification

+ [github project] (https://github.com/geronime/sinatra-enotify)

sinatra-enotify is simple exception notification extension module to sinatra.

## Requirements:

Optional redis exception cache requires `redis` and `yajl-ruby` gems.
These are not defined as dependency of `sinatra-enotify` to leave the plain
version available.

## Usage:

Register the extension in sinatra:

    Sinatra::register Sinatra::ENotify

This will register three helper functions `configure_enotify`, `enotify`
and `ecache_cleanup`.

The `ecache_cleanup` is only relevant for enabled redis exception cache.

### Configuration:

Default configuration for the `enotify` function is to output to _STDERR_.
For `enotify` configuration use `configure_enotify` function.

#### Configure e-mailing:

    configure_enotify({
      :notify  => true,
      :basedir => File.expand_path(File.join(File.dirname(__FILE__), '..')),
      :prefix  => '[MyApp]', # prefix prepended to e-mail subject
      :from    => 'www@myapp.mydomain.com',
      :rcpt    => 'exceptions@mydomain.com', # or an Array of recipients
    })

The `:basedir` configuration specifies to strip this path from all the trace
lines within such location for better readability. Set it back to `nil`
in order to disable this feature.

#### Ignore exceptions:

To completely disable notification either via mail or to _STDERR_:

    configure_enotify({:ignore => true})

To return to previous configuration just set `:ignore` back to false.

#### Configure redis exception cache:

Since __0.0.2__ it is possible to configure redis exception cache in order to
report the same exceptions only once per defined time period at most.

The following example contains default values therefore all of them are optional:

    configure_enotify({
      :redis => {
        :host   => '127.0.0.1',
        :port   => 6379,
        :dbid   => 0,
        :expire => 3600,
        :limit  => 100,
      },
    })

  + options `:host`, `:port` and `:dbid` do not need any explanation
  + option `:db` takes precedence to `:dbid` and specifies database name for
  [ReDBis wrapper] (https://github.com/geronime/redbis) usage (new in __0.0.5__)
  + `:expire` specifies the time period in seconds for which the data
  in the exception cache are kept as valid
    + this is the minimal period between the two reports of the same exceptions
  (with the same trace)
  + `:limit` limits the number of the most recent exceptions with unique
  non-empty GET/POST data to be included in the notification

To disable the redis exception cache just set the `:redis` back to `nil`.

__NOTE__: In __0.0.6__ a possible redis connection race condition is treated.
Use of sinatra-enotify in `rainbows`-based solutions with `preload_app=true`,
multiple workers used and `configure_enotify` done in the preload part
of the sinatra application could lead to redis connection race condition.
It is important that each worker has its own redis connection.

### Include enotify in your code:

To include the notification just cover the code in your request blocks
with `begin`-`rescue`-`end` block. Example:

    get '/' do
      begin
        ... # do the stuff
      rescue Exception => e
        enotify e
        ... # return some error page
      end
    end

Or just use it to notify some string error (new in __0.0.7__):

    enotify "Error message goes here."

## Changelog:

+ __0.0.7__: possibility to enotify simple error string message
+ __0.0.6__: redis connection is reinitialized upon first cache request
+ __0.0.5__: redis exception cache accepts :db option for
  [ReDBis wrapper] (https://github.com/geronime/redbis)
+ __0.0.4__: e-mails with standard date format in header
+ __0.0.3__: only _unique_ GET/POST data combinations are included
  in notifications with redis exception cache enabled
+ __0.0.2__: optional redis exception cache added
+ __0.0.1__: first revision of simple exception notifier

## License:

sinatra-enotify is copyright (c)2011 Jiri Nemecek, and released under the terms
of the MIT license. See the LICENSE file for the gory details.

