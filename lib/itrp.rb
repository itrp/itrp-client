require 'gem_config'
require 'logger'

module Itrp
  include GemConfig::Base

  with_configuration do
    has :logger, classes: ::Logger, default: ::Logger.new(STDOUT)

    has :host, classes: String, default: 'https://api.itrp.com'
    has :api_version, values: ['v1'], default: 'v1'
    has :api_token, classes: String

    has :account, classes: String
    has :source, classes: String

    has :max_retry_time, classes: Fixnum, default: 5400
    has :read_timeout, classes: Fixnum, default: 25
    has :block_at_rate_limit, classes: [TrueClass, FalseClass], default: false

    has :proxy_host, classes: String
    has :proxy_port, classes: Fixnum, default: 8080
    has :proxy_user, classes: String
    has :proxy_password, classes: String

    has :ca_file, classes: String, default: '../ca-bundle.crt'
  end

  def self.logger
    configuration.logger
  end

  class Exception < ::Exception; end # ::Itrp::Exception class

  class UploadFailed < Exception; end # ::Itrp::UploadFailed class

end