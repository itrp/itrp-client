# -*- encoding : utf-8 -*-
dir = File.dirname(__FILE__)
$LOAD_PATH.unshift dir + '/../lib'
$LOAD_PATH.unshift dir

STDERR.puts("Running specs using ruby version #{RUBY_VERSION}")

require 'simplecov'
SimpleCov.start

require 'rspec'
require 'webmock/rspec'

# Patch for https://github.com/bblimke/webmock/issues/623
module WebMock
  class BodyPattern
    def assert_non_multipart_body(content_type)
      # if content_type =~ %r{^multipart/form-data}
      #   raise ArgumentError.new("WebMock does not support matching body for multipart/form-data requests yet :(")
      # end
    end
  end
end

require 'itrp/client'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir["#{dir}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.before(:each) do
    log_dir = File.dirname(__FILE__) + '/log'
    Dir.mkdir(log_dir) unless File.exists?(log_dir)
    Itrp.configuration.logger = Logger.new("#{log_dir}/test.log")
    @spec_dir = dir
    @fixture_dir = "#{dir}/support/fixtures"
  end
  config.after(:each) { Itrp.configuration.reset }

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"

end

