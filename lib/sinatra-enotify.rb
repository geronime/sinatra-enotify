#encoding:utf-8
require 'net/smtp'

require 'sinatra-enotify/format'

module Sinatra

	module ENotify

		def self.registered app
			app.helpers Sinatra::ENotify
		end

		# Configure mailing options for the enotify function.
		# Default is to output the notification to STDERR.
		# Options are stored in @@_ENOTIFY variable.
		#   :ignore  - disables the exception notification at all (default false)
		#              (enotify function does nothing with this enabled)
		#   :notify  - enable emailing of the reports, default false (STDERR output)
		#             when enabled, following configuration should be provided
		#   :basedir - basic project directory - the trace is stripped of this path
		#              for better readability (default nil)
		#   :from    - source email address, e.g. www@myapp.mydomain.com
		#   :rcpt    - recipient email address (or array of addresses)
		#   :prefix  - subject prefix, e.g. '[MyApp]'
		#   :redis   - enable redis caching mechanism
		# Empty opts hash sets sets both :ignore and :notify to false
		def configure_enotify opts={}
			o = defined?(@@_ENOTIFY) ? @@_ENOTIFY : {}
			if opts.empty?
				o[:ignore], o[:notify] = false, false
			elsif opts[:ignore]
				o[:ignore] = true
			else
				o[:notify] = opts[:notify] ? true : false if opts.key? :notify
				[:basedir, :from, :prefix].each{|opt|
					if opts.key? opt
						if ! opts[opt]
							o[opt] = opt == :prefix ? '' : nil
						elsif opts[opt].kind_of? String
							o[opt] = opts[opt]
						else
							throw "String expected for #{opt} option!"
						end
					end
				}
				o[:from] = nil if o[:from] && o[:from].empty?
				if opts.key? :rcpt
					if ! opts[:rcpt]
						o[:rcpt] = nil
					elsif opts[:rcpt].kind_of?(String) || opts[:rcpt].kind_of?(Array)
						o[:rcpt] = opts[:rcpt]
					else
						throw "String or Array expected for :rcpt option!"
					end
					o[:rcpt] = nil if o[:rcpt].empty?
				end
			end
			if o[:notify]
				[:from, :rcpt].each{|opt|
					throw 'Missing required :from option for enabled notification!' \
						unless o[opt]
				}
			end
			if opts.key? :redis
				if opts[:redis]
					require 'sinatra-enotify/exception_cache'
					throw 'Hash expected for defined :redis option!' \
						unless opts[:redis].kind_of? Hash
					@@_REDIS = ExceptionCache.new opts[:redis]
				else
					@@_REDIS = nil
				end
			end
			@@_ENOTIFY = o
		end

		def ecache_cleanup
			@@_REDIS.cleanup if defined? @@_REDIS && @@_REDIS
		end

		# Report exception e.
		def enotify e
			throw 'Sinatra::ENotify not configured!' unless defined? @@_ENOTIFY
			return if @@_ENOTIFY[:ignore]
			basedir_length = @@_ENOTIFY[:basedir].length + 1 if @@_ENOTIFY[:basedir]
			time, report, err, trace = Time.now, '', "#{e.class}: #{e.message}",
				'  ' + e.backtrace.collect{|ln|
					@@_ENOTIFY[:basedir] ?
						ln.start_with?(@@_ENOTIFY[:basedir]) ?
							ln[basedir_length..-1] :
							ln :
						ln
				}.join("\n  ")
			if @@_REDIS
				data = {}
				['GET', 'POST'].each{|method|
					d = request.send(method) and !d.empty? and data[method] = d }
				report = @@_REDIS.report? time, err, trace, data
				return if report.kind_of? Float # already reported
			end
			get_data, post_data =
				Format.format('GET', request.GET), Format.format('POST', request.POST)
			if @@_ENOTIFY[:notify]
				from, to, prefix = *@@_ENOTIFY.values_at(:from, :rcpt, :prefix)
				msg =
					"From: #{from}\r\n" +
					"To: #{to.kind_of?(Array) ? to.join(', ') : to}\r\n" +
					"Date: #{time}\r\n" +
					"Subject: #{prefix} #{err}\r\n\r\n" +
					"#{time.strftime '%Y-%m-%d %H:%M:%S.%L'} - #{err}\n\n" +
					"Trace:\n#{trace}\n\n#{get_data}\n\n#{post_data}#{report}\n\n" +
					"-- \nsinatra-enotify exception mailer.\n\n"
				Net::SMTP.start('localhost'){|smtp| smtp.send_message(msg, from, to) }
			else
				warn "#{time.strftime '%Y-%m-%d %H:%M:%S.%L'} - #{err}\n\n" +
					"Trace:\n#{trace}\n\n#{get_data}\n\n#{post_data}#{report}"
			end
		end

	end # ENotify

end # Sinatra

