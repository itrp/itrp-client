# -*- encoding : utf-8 -*-
dir = File.dirname(__FILE__)
$LOAD_PATH.unshift dir + '/../lib'
$LOAD_PATH.unshift dir

STDERR.puts("Running specs using ruby version #{RUBY_VERSION}")

require 'rspec'
require 'rr'
require 'webmock/rspec'

require 'itrp/client'

# $LOAD_PATH.unshift dir + '/../app/models'

RSpec.configure do |config|
  config.mock_with :rr
  config.before(:each) do
    log_dir = File.dirname(__FILE__) + '/log'
    Dir.mkdir(log_dir) unless File.exists?(log_dir)
    Itrp.configuration.logger = Logger.new("#{log_dir}/test.log")
  end
  config.after(:each) { Itrp.configuration.reset }
end

