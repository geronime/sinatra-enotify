# sinatra-enotify - Sinatra exception notification

+ [github project] (https://github.com/geronime/sinatra-enotify)

sinatra-enotify is simple exception notification extension module to sinatra.

## Usage

Register the extension in sinatra:

    Sinatra::register Sinatra::ENotify

This will register two helper functions `configure_enotify` and `enotify`.

### `enotify` configuration:

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

### Include enotify in your code

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

## License

sinatra-enotify is copyright (c)2011 Jiri Nemecek, and released under the terms
of the MIT license. See the LICENSE file for the gory details.


