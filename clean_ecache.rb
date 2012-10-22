#!/usr/bin/env ruby
#encoding:utf-8
require 'bundler/setup'
require 'docopt'
require 'sinatra-enotify/exception_cache'

help = <<DOCOPT
Clean sinatra-enotify Redis exception cache.

Usage:
  #{__FILE__} -h | --help
  #{__FILE__} [-e <expire>] [-H <host>] [-p <port>] [-i <db_id>]
  #{__FILE__} [-e <expire>] [-H <host>] [-p <port>] <db_name>

Options:
  -h, --help
  -e <expire>, --expire=<expire>  Set expiration for exceptions [default: 3600]
  -H <host>, --host=<host>        Set redis host name [default: 127.0.0.1]
  -p <port>, --port=<port>        Set redis port [default: 6379]
  -i <db_id>, --id=<db_id>        Specify Redis database id [default: 0]
  <db_name>                       Specify ReDBis DB name [default: nil]
DOCOPT

begin
  args = Docopt::docopt help
rescue Docopt::Exit => e
  puts "\n" + e.message + "\n\n"
  exit 1
end

o = {
  :host   => args.delete('--host'),
  :port   => args.delete('--port').to_i,
  :expire => args.delete('--expire').to_i,
}
args['<db_name>'] ?
  (o[:db] = args['<db_name>']) :
  (o[:dbid] = args['--id'].to_i)

Sinatra::ENotify::ExceptionCache.new(o).cleanup
exit 0

