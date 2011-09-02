# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'sinatra-enotify/version'

Gem::Specification.new do |s|
	s.name        = 'sinatra-enotify'
	s.version     = Sinatra::ENotify::VERSION
	s.platform    = Gem::Platform::RUBY
	s.authors     = ['Jiri Nemecek']
	s.email       = ['nemecek.jiri@gmail.com']
	s.homepage    = ''
	s.summary     = %q{Sinatra exception notification}
	s.description = %q{sinatra-enotify is simple exception notification
	                   extension module to sinatra.}

	s.rubyforge_project = 'sinatra-enotify'

	s.files         = `git ls-files`.split("\n")
	s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
	s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
	s.require_paths = ['lib']
end
