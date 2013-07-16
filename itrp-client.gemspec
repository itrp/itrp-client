# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'itrp/client/version'

Gem::Specification.new do |spec|
  spec.name          = "itrp-client"
  spec.version       = Itrp::Client::VERSION
  spec.authors       = ["ITRP"]
  spec.email         = %q{developers@itrp.com}
  spec.description   = %q{Client for accessing the ITRP REST API}
  spec.summary       = %q{Client for accessing the ITRP REST API}
  spec.homepage      = "https://developer.itrp.com"
  spec.license       = "MIT"

  spec.files = Dir.glob("lib/**/*") + [
      "LICENSE.txt",
      "README.md",
      "Gemfile",
      "Gemfile.lock",
      "itrp-client.gemspec"
  ]
  spec.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  spec.test_files    = `git ls-files -- {test,spec}/*`.split("\n")
  spec.require_paths = ["lib"]
  spec.rdoc_options = ["--charset=UTF-8"]

  spec.add_runtime_dependency 'gem_config'

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rr"
  spec.add_development_dependency "webmock"
end
