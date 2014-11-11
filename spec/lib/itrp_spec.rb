require 'spec_helper'

describe Itrp do
  it "should define a default configuration" do
    conf = Itrp.configuration.current

    conf.keys.sort.should == [:account, :api_token, :api_version, :block_at_rate_limit, :ca_file, :host, :logger, :max_retry_time, :proxy_host, :proxy_password, :proxy_port, :proxy_user, :read_timeout, :source]

    conf[:logger].class.should == ::Logger
    conf[:host].should == 'https://api.itrp.com'
    conf[:api_version].should == 'v1'

    conf[:max_retry_time].should == 5400
    conf[:read_timeout].should == 25
    conf[:block_at_rate_limit].should == false

    conf[:proxy_port].should == 8080

    [:api_token, :account, :source, :proxy_host, :proxy_user, :proxy_password].each do |no_default|
      conf[no_default].should == nil
    end

    conf[:ca_file].should == '../ca-bundle.crt'
  end

  it "should define a logger" do
    Itrp.logger.class.should == ::Logger
  end

  it "should define an exception class" do
    expect { raise ::Itrp::Exception.new('test') }.to raise_error('test')
  end
end