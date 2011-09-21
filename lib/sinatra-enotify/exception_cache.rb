#encoding:utf-8
require 'digest/md5'
require 'redis'
require 'yajl'

require 'sinatra-enotify/format'

module Sinatra

	module ENotify

		class ExceptionCache

			# Data stored in the database - for each exception keep a document:
			# document key = md5sum_of_error-md5sum_of_trace
			# each document is a hash:
			#   {last_report => epoch, epoch => [GET_data, POST_DATA],...}

			# available options and defaults:
			# host
			# port    - specify host/port where redis is running (127.0.0.1:6379)
			# dbid    - specify redis database index (0)
			# flush   - flush the database during the initialization (false)
			# expire  - specify expiration of recorded exceptions in seconds (3600)
			# limit   - specify default limit of unique non-empty unexpired GET/POST
			#           data to be included in the notification (100)
			def initialize o={}
				@r = Redis.new(
						:host => o[:host] || '127.0.0.1', :port => o[:port] || 6379)
				@r.select o[:dbid] if o[:dbid]
				@r.flushdb if o[:flush]
				@exp = o[:expire] ? o[:expire].to_i : 3600
				@limit = o[:limit] ? o[:limit].to_i : 100
			end

			# Clean expired data from the database.
			# key - clean data within specified exception key (all otherwise)
			def cleanup key=nil
				exp_epoch = Time.now.to_f - @exp
				docs = key ? [key] : @r.keys('*')
				docs.each{|doc|
					next unless @r.exists doc
					last = @r.hget doc, 'last_report'
					@r.hdel doc, 'last_report' if last && last.to_f < exp_epoch
					arr = @r.hkeys doc
					last = arr.delete 'last_report'
					arr.each{|epoch| @r.hdel doc, epoch if epoch.to_f < exp_epoch }
					@r.del doc if arr.empty? && !last
				}
			end

			# Determine whether to report passed exception:
			# 1. record exception in the database
			# 2. run cleanup for the current exception
			# 3. if last_report is recorded there is nothing to report:
			#    return the last_report fractional epoch time as Float
			# 4. record current epoch to last_report
			# 5. assemble up-to limit non-empty unique combinations of GET/POST data
			# 6. return String of assembled GET/POST data combinations
			#    to be included in the notifications
			# data = {'GET' => {get data}, 'POST' => {post data}}
			#        keys are not to be defined in case of empty data
			def report? time, err, trace, data={}, limit=@limit
				curr_epoch, doc = sprintf('%.6f', time.to_f), doc_key(err, trace)
				record curr_epoch, doc, data
				cleanup doc
				10.times{
					@r.watch doc
					last = @r.hget doc, 'last_report'
					return last.to_f if last
					@r.multi
					@r.hset doc, 'last_report', curr_epoch
					break if @r.exec
				} # this should prevent other processes to report again
				added, uniq_data, arr = [], {}, @r.hkeys(doc)
				arr.delete 'last_report'
				arr.delete curr_epoch
				return '' if arr.empty? # nothing to add to the report
				s = sprintf \
						"\n\nThe same exception occured %u times during last %u secs.",
						arr.length, @exp
				arr.reverse_each{|epoch|
					if d = @r.hget(doc, epoch)
						d = Yajl::Parser.parse d
						d == data || uniq_data[d] ? next : (uniq_data[d] = 1)
						added.push([epoch, d])
						last if limit == added.length
					end
				}
				return s +
						"\nNone of those contained different non-empty GET/POST data." \
					if added.empty?
				# add the assembled data
				s += sprintf \
						"\n\nUnique non-empty GET/POST data of %s most recent one%s:",
						*(added.length == 1 ? ['the', ''] : ["#{added.length}", 's'])
				added.each{|d|
					s += sprintf "\n\nTime: %s\n\n%s\n\n%s",
							Time.at(d[0].to_f).strftime('%Y-%m-%d %H:%M:%S.%L'),
							Sinatra::ENotify::Format.format('GET', d[1]['GET']),
							Sinatra::ENotify::Format.format('POST', d[1]['POST'])
				}
				s
			end

			private

			# Compute document key - md5sum_of_error-md5sum_of_trace
			def doc_key err, trace
				Digest::MD5.hexdigest(err) + '-' + Digest::MD5.hexdigest(trace)
			end

			def record time, doc, data={}
				@r.hset doc, time, Yajl::Encoder.encode(data)
			end

		end # ExceptionCache

	end # ENotify

end # Sinatra

