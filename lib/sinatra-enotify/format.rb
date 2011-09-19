#encoding:utf-8

module Sinatra

	module ENotify

		module Format

			def self.format method, data
				unless data && !data.empty?
					"No #{method} data."
				else
					s, maxlen = "#{method} data:", 0
					data.each_key{|k|
						maxlen = k.to_s.length + 1 if k.to_s.length >= maxlen }
					data.sort_by{|k, v| k.to_s }.each{|key, val|
						s += sprintf "\n  %-#{maxlen}s= %s", key, val.inspect }
					s
				end
			end

		end # Format

	end # ENotify

end # Sinatra

