require 'spec_helper'

describe Itrp do
  it "should define a default configuration" do
    conf = Itrp.configuration.current

    expect(conf.keys.sort).to eq([:account, :api_token, :api_version, :block_at_rate_limit, :ca_file, :host, :logger, :max_retry_time, :proxy_host, :proxy_password, :proxy_port, :proxy_user, :read_timeout, :source])

    expect(conf[:logger].class).to eq(::Logger)
    expect(conf[:host]).to eq('https://api.itrp.com')
    expect(conf[:api_version]).to eq('v1')

    expect(conf[:max_retry_time]).to eq(5400)
    expect(conf[:read_timeout]).to eq(25)
    expect(conf[:block_at_rate_limit]).to be_falsey

    expect(conf[:proxy_port]).to eq(8080)

    [:api_token, :account, :source, :proxy_host, :proxy_user, :proxy_password].each do |no_default|
      expect(conf[no_default]).to be_nil
    end

    expect(conf[:ca_file]).to eq('../ca-bundle.crt')
  end

  it "should define a logger" do
    expect(Itrp.logger.class).to eq(::Logger)
  end

  it "should define an exception class" do
    expect { raise ::Itrp::Exception.new('test') }.to raise_error('test')
  end
end