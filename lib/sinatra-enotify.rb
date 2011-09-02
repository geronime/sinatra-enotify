#encoding:utf-8
require 'net/smtp'

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
			@@_ENOTIFY = o
		end

		# Report exception e.
		def enotify e
			return if @@_ENOTIFY[:ignore]
			basedir_length = @@_ENOTIFY[:basedir].length + 1 if @@_ENOTIFY[:basedir]
			trace = '  ' + e.backtrace.collect{|ln|
				@@_ENOTIFY[:basedir] ?
					ln.start_with?(@@_ENOTIFY[:basedir]) ?
						ln[basedir_length..-1] :
						ln :
					ln
			}.join("\n  ")
			tstamp = Time.now.strftime '%Y-%m-%d %H:%M:%S.%L'
			get_data, post_data = nil, nil
			if request.GET.empty?
				get_data = 'No GET data.'
			else
				get_data, maxlen = "GET data:", 0
				request.GET.each_key{|k| maxlen = k.length + 1 if k.length >= maxlen }
				request.GET.sort_by{|k, v| k.to_s }.each{|key, val|
					get_data += sprintf "\n  %-#{maxlen}s= %s", key, val.inspect
				}
			end
			if request.POST.empty?
				post_data = 'No POST data.'
			else
				post_data, maxlen = "POST data:", 0
				request.POST.each_key{|k| maxlen = k.length + 1 if k.length >= maxlen }
				request.POST.sort_by{|k, v| k.to_s }.each{|key, val|
					post_data += sprintf "\n  %-#{maxlen}s= %s", key, val.inspect
				}
			end
			if @@_ENOTIFY[:notify]
				from, to, prefix = *@@_ENOTIFY.values_at(:from, :rcpt, :prefix)
				msg =
					"From: #{from}\r\n" +
					"To: #{to.kind_of?(Array) ? to.join(', ') : to}\r\n" +
					"Date: #{Time.now}\r\n" +
					"Subject: #{prefix} #{e.class}: #{e.message}\r\n\r\n" +
					"#{tstamp} - #{e.class}: #{e.message}\n\n" +
					"Trace:\n#{trace}\n\n#{get_data}\n\n#{post_data}\n\n" +
					"-- \nsinatra-enotify mailer.\n\n"
				Net::SMTP.start('localhost'){|smtp| smtp.send_message(msg, from, to) }
			else
				warn "#{tstamp} - #{e.class}: #{e.message}\n\nTrace:\n#{trace}\n\n" +
					"#{get_data}\n\n#{post_data}"
			end
		end

	end

end

