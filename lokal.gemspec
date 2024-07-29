lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'lokal/version'

Gem::Specification.new do |spec|
  spec.name          = "lokal"
  spec.version       = Lokal::VERSION
  spec.authors       = ["Rubi Jihantoro"]
  spec.email         = ["ceo@lokal.so"]

  spec.summary       = %q{Ruby Gem for interacting with Lokal Client REST API}
  spec.description   = %q{Ruby Gem for interacting with Lokal Client REST API, Lokal Client installation area required in order to use this gem}
  spec.homepage      = "https://github.com/lokal-so/lokal-rb"
  spec.homepage      = %q{http://rubygems.org/gems/lokal-rb}
  spec.license       = "MIT"


  spec.files         = ["Rakefile", "lib/lokal.rb", "lib/lokal/version.rb"]
  spec.bindir        = "exe"
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.7.11"
  spec.add_dependency "semantic", "~> 1.6.1"
	spec.add_dependency "colorize", "~> 0.8.1"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
