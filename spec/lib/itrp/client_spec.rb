require 'spec_helper'

describe Itrp::Client do

  context 'Itrp.config' do
    before(:each) do
      Itrp.configure do |config|
        config.max_retry_time = 120 # override default value (5400)
        config.api_token = 'secret' # set value
      end
    end

    it 'should define the MAX_PAGE_SIZE' do
      Itrp::Client::MAX_PAGE_SIZE.should == 100
    end

    it 'should use the Itrp configuration' do
      client = Itrp::Client.new
      client.option(:host).should == 'https://api.itrp.com' # default value
      client.option(:api_token).should == 'secret'          # value set using Itrp.config
      client.option(:max_retry_time).should == 120          # value overridden in Itrp.config
    end

    it 'should override the Itrp configuration' do
      client = Itrp::Client.new(host: 'https://demo.itrp.com', api_token: 'unknown', block_at_rate_limit: true)
      client.option(:read_timeout).should == 60              # default value
      client.option(:host).should == 'https://demo.itrp.com' # default value overridden in Client.new
      client.option(:api_token).should == 'unknown'          # value set using Itrp.config and overridden in Client.new
      client.option(:max_retry_time).should == 120           # value overridden in Itrp.config
      client.option(:block_at_rate_limit).should == true     # value overridden in Client.new
    end

    [:host, :api_version, :api_token].each do |required_option|
      it "should require option #{required_option}" do
        expect { Itrp::Client.new(required_option => '') }.to raise_error("Missing required configuration option #{required_option}")
      end
    end

    [ ['https://api.itrp.com',        true,  'api.itrp.com',     443],
      ['https://api.example.com:777', true,  'api.example.com',  777],
      ['http://itrp.example.com',     false, 'itrp.example.com', 80],
      ['http://itrp.example.com:777', false, 'itrp.example.com', 777]
    ].each do |host, ssl, domain, port|
      it 'should parse ssl, host and port' do
        client = Itrp::Client.new(host: host)
        client.instance_variable_get(:@ssl).should == ssl
        client.instance_variable_get(:@domain).should == domain
        client.instance_variable_get(:@port).should == port
      end
    end
  end

  it 'should set the ca-bundle.crt file' do
    http = Net::HTTP.new('https://api.itrp.com')
    http.use_ssl = true

    on_disk = `ls #{http.ca_file}`
    on_disk.should_not =~ /cannot access/
    on_disk.should =~ /\/ca-bundle.crt$/
  end

  describe 'headers' do
    before(:each) do
      @client = Itrp::Client.new(api_token: 'secret', max_retry_time: -1)
    end

    it 'should set the content type header' do
      stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/me').with(headers: {'Content-Type' => 'application/json'}).to_return(body: {name: 'my name'}.to_json)
      response = @client.get('me')
      stub.should have_been_requested
    end

    it 'should add the X-ITRP-Account header' do
      client = Itrp::Client.new(api_token: 'secret', max_retry_time: -1, :account => 'test')
      stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/me').with(headers: {'X-ITRP-Account' => 'test'}).to_return(body: {name: 'my name'}.to_json)
      response = client.get('me')
      stub.should have_been_requested
    end

    it 'should add the X-ITRP-Source header' do
      client = Itrp::Client.new(api_token: 'secret', max_retry_time: -1, :source => 'myapp')
      stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/me').with(headers: {'X-ITRP-Source' => 'myapp'}).to_return(body: {name: 'my name'}.to_json)
      response = client.get('me')
      stub.should have_been_requested
    end

    it 'should be able to override headers' do
      stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/me').with(headers: {'Content-Type' => 'application/x-www-form-urlencoded'}).to_return(body: {name: 'my name'}.to_json)
      response = @client.get('me', {}, {'Content-Type' => 'application/x-www-form-urlencoded'})
      stub.should have_been_requested
    end

    it 'should set the other headers' do
      stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/me').with(headers: {'X-ITRP-Other' => 'value'}).to_return(body: {name: 'my name'}.to_json)
      response = @client.get('me', {}, {'X-ITRP-Other' => 'value'})
      stub.should have_been_requested
    end

  end

  context 'each' do
    before(:each) do
      @client = Itrp::Client.new(api_token: 'secret', max_retry_time: -1)
    end

    it 'should yield each result' do
      stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/requests?fields=subject&page=1&per_page=100').to_return(body: [{id: 1, subject: 'Subject 1'}, {id: 2, subject: 'Subject 2'}, {id: 3, subject: 'Subject 3'}].to_json)
      nr_of_requests = @client.each('requests', {fields: 'subject'}) do |request|
        request[:subject].should == "Subject #{request[:id]}"
      end
      nr_of_requests.should == 3
    end

    it 'should retrieve multiple pages' do
      stub_page1 = stub_request(:get, 'https://secret:@api.itrp.com/v1/requests?page=1&per_page=2').to_return(body: [{id: 1, subject: 'Subject 1'}, {id: 2, subject: 'Subject 2'}].to_json, headers: {'Link' => '<https://api.itrp.com/v1/requests?page=1&per_page=2>; rel="first",<https://api.itrp.com/v1/requests?page=2&per_page=2>; rel="next",<https://api.itrp.com/v1/requests?page=2&per_page=2>; rel="last"'})
      stub_page2 = stub_request(:get, 'https://secret:@api.itrp.com/v1/requests?page=2&per_page=2').to_return(body: [{id: 3, subject: 'Subject 3'}].to_json, headers: {'Link' => '<https://api.itrp.com/v1/requests?page=1&per_page=2>; rel="first",<https://api.itrp.com/v1/requests?page=1&per_page=2>; rel="prev",<https://api.itrp.com/v1/requests?page=2&per_page=2>; rel="last"'})
      nr_of_requests = @client.each('requests', {per_page: 2}) do |request|
        request[:subject].should == "Subject #{request[:id]}"
      end
      nr_of_requests.should == 3
      stub_page2.should have_been_requested
    end
  end

  context 'get' do
    before(:each) do
      @client = Itrp::Client.new(api_token: 'secret', max_retry_time: -1)
    end

    it 'should return a response' do
      stub_request(:get, 'https://secret:@api.itrp.com/v1/me').to_return(body: {name: 'my name'}.to_json)
      response = @client.get('me')
      response[:name].should == 'my name'
    end

    describe 'parameters' do

      [[nil, ''],
       [ 'normal',     'normal'],
       [ 'hello;<',    'hello%3B%3C'],
       [ true,         'true'],
       [ false,        'false'],
       [ DateTime.now, DateTime.now.new_offset(0).iso8601],
       [ Date.new,     Date.new.strftime('%Y-%m-%d')],
       [ Time.now,     Time.now.strftime('%H:%M')],
       [ ['first', 'second;<', true], 'first,second%3B%3C,true']
      ].each do |param_value, url_value|
        it "should cast #{param_value.class.name}: '#{param_value}' to '#{url_value}'" do
          stub = stub_request(:get, "https://secret:@api.itrp.com/v1/me?value=#{url_value}").to_return(body: {name: 'my name'}.to_json)
          response = @client.get('me', {value: param_value})
          stub.should have_been_requested
        end
      end

      it 'should handle fancy filter operations' do
        now = DateTime.now
        stub = stub_request(:get, "https://secret:@api.itrp.com/v1/people?created_at=>#{now.new_offset(0).iso8601}&id!=15").to_return(body: {name: 'my name'}.to_json)
        response = @client.get('people', {'created_at=>' => now, 'id!=' => 15})
        stub.should have_been_requested
      end

      it 'should append parameters' do
        now = DateTime.now
        stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/people?id!=15&primary_email=me@example.com').to_return(body: {name: 'my name'}.to_json)
        response = @client.get('people?id!=15', {'primary_email' => 'me@example.com'})
        stub.should have_been_requested
      end
    end
  end

  context 'put' do
    it 'should send put requests with parameters and headers' do
      client = Itrp::Client.new(api_token: 'secret', max_retry_time: -1)
      stub = stub_request(:put, 'https://secret:@api.itrp.com/v1/people/1').with(body: {'name' => 'New Name'}, headers: {'X-ITRP-Custom' => 'custom'}).to_return(body: {id: 1}.to_json)
      response = client.put('people/1', {'name' => 'New Name'}, {'X-ITRP-Custom' => 'custom'})
      stub.should have_been_requested
    end
  end

  context 'post' do
    it 'should send post requests with parameters and headers' do
      client = Itrp::Client.new(api_token: 'secret', max_retry_time: -1)
      stub = stub_request(:post, 'https://secret:@api.itrp.com/v1/people').with(body: {'name' => 'New Name'}, headers: {'X-ITRP-Custom' => 'custom'}).to_return(body: {id: 101}.to_json)
      response = client.post('people', {'name' => 'New Name'}, {'X-ITRP-Custom' => 'custom'})
      stub.should have_been_requested
    end
  end

  context 'import' do
    it 'should import a CSV file' do

    end
  end

  context 'retry' do
    it 'should not retry when max_retry_time = -1' do
      stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/me').to_raise(StandardError.new('network error'))
      expect_log('Sending GET request to api.itrp.com:443/v1/me', :debug )
      expect_log("Request failed: No Response from Server - network error for 'api.itrp.com:443/v1/me'", :error)

      client = Itrp::Client.new(api_token: 'secret', max_retry_time: -1)
      response = client.get('me')
      stub.should have_been_requested.times(1)
      response.valid?.should == false
      response.message.should == "No Response from Server - network error for 'api.itrp.com:443/v1/me'"
    end

    it 'should not retry 4 times when max_retry_time = 16' do
      stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/me').to_raise(StandardError.new('network error'))
      [2,4,8,16].each_with_index do |secs, i|
        expect_log('Sending GET request to api.itrp.com:443/v1/me', :debug )
        expect_log("Request failed, retry ##{i+1} in #{secs} seconds: No Response from Server - network error for 'api.itrp.com:443/v1/me'", :warn)
      end

      client = Itrp::Client.new(api_token: 'secret', max_retry_time: 16)
      allow(client).to receive(:sleep)
      response = client.get('me')
      stub.should have_been_requested.times(4)
      response.valid?.should == false
      response.message.should == "No Response from Server - network error for 'api.itrp.com:443/v1/me'"
    end

    it 'should return the response after retry succeeds' do
      stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/me').to_raise(StandardError.new('network error')).then.to_return(body: {name: 'my name'}.to_json)
      expect_log('Sending GET request to api.itrp.com:443/v1/me', :debug )
      expect_log("Request failed, retry #1 in 2 seconds: No Response from Server - network error for 'api.itrp.com:443/v1/me'", :warn)
      expect_log('Sending GET request to api.itrp.com:443/v1/me', :debug )
      expect_log(%(Response:\n{\n  "name": "my name"\n}), :debug )

      client = Itrp::Client.new(api_token: 'secret', max_retry_time: 16)
      allow(client).to receive(:sleep)
      response = client.get('me')
      stub.should have_been_requested.times(2)
      response.valid?.should == true
      response[:name].should == 'my name'
    end
  end

  context 'rate limiting' do
    it 'should not block on rate limit when block_at_rate_limit is false' do
      stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/me').to_return(:status => 429, :body => {message: 'Too Many Requests'}.to_json)
      expect_log('Sending GET request to api.itrp.com:443/v1/me', :debug )
      expect_log("Request failed: Too Many Requests", :error)

      client = Itrp::Client.new(api_token: 'secret', block_at_rate_limit: false)
      response = client.get('me')
      stub.should have_been_requested.times(1)
      response.valid?.should == false
      response.message.should == 'Too Many Requests'
    end

    it 'should block on rate limit when block_at_rate_limit is true' do
      stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/me').to_return(:status => 429, :body => {message: 'Too Many Requests'}.to_json).then.to_return(body: {name: 'my name'}.to_json)
      expect_log('Sending GET request to api.itrp.com:443/v1/me', :debug )
      expect_log('Request throttled, trying again in 5 minutes: Too Many Requests', :warn)
      expect_log('Sending GET request to api.itrp.com:443/v1/me', :debug )
      expect_log(%(Response:\n{\n  "name": "my name"\n}), :debug )

      client = Itrp::Client.new(api_token: 'secret', block_at_rate_limit: true)
      allow(client).to receive(:sleep)
      response = client.get('me')
      stub.should have_been_requested.times(2)
      response.valid?.should == true
      response[:name].should == 'my name'
    end
  end

  context 'logger' do
    before(:each) do
      @logger = Logger.new(STDOUT)
      @client = Itrp::Client.new(api_token: 'secret', max_retry_time: -1, logger: @logger)
    end

    it 'should be possible to override the default logger' do
      stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/me').to_return(body: {name: 'my name'}.to_json)
      expect_log('Sending GET request to api.itrp.com:443/v1/me', :debug, @logger )
      expect_log(%(Response:\n{\n  "name": "my name"\n}), :debug, @logger )
      response = @client.get('me')
    end
  end
end
