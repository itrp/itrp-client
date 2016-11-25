# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'itrp/client/version'

Gem::Specification.new do |spec|
  spec.name                  = "itrp-client"
  spec.version               = Itrp::Client::VERSION
  spec.platform              = Gem::Platform::RUBY
  spec.required_ruby_version = '>= 2.0.0'
  spec.authors               = ["ITRP"]
  spec.email                 = %q{developers@itrp.com}
  spec.description           = %q{Client for accessing the ITRP REST API}
  spec.summary               = %q{Client for accessing the ITRP REST API}
  spec.homepage              = %q{http://github.com/itrp/itrp-client}
  spec.license               = "MIT"

  spec.files = Dir.glob("lib/**/*") + %w(
    LICENSE.txt
    README.md
    Gemfile
    Gemfile.lock
    itrp-client.gemspec
  )
  spec.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  spec.test_files    = `git ls-files -- {test,spec}/*`.split("\n")
  spec.require_paths = ["lib"]
  spec.rdoc_options = ["--charset=UTF-8"]

  spec.add_runtime_dependency 'gem_config'
  spec.add_runtime_dependency 'activesupport'
  spec.add_runtime_dependency 'mime-types'

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency 'rspec', "~> 3.3.0"
  spec.add_development_dependency 'webmock', "~> 2"
  spec.add_development_dependency 'simplecov'

end
