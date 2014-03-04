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
      client.option(:read_timeout).should == 25              # default value
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
      client = Itrp::Client.new(api_token: 'secret', max_retry_time: -1, account: 'test')
      stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/me').with(headers: {'X-ITRP-Account' => 'test'}).to_return(body: {name: 'my name'}.to_json)
      response = client.get('me')
      stub.should have_been_requested
    end

    it 'should add the X-ITRP-Source header' do
      client = Itrp::Client.new(api_token: 'secret', max_retry_time: -1, source: 'myapp')
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
        response = @client.get('people?id!=15', {primary_email: 'me@example.com'})
        stub.should have_been_requested
      end
    end
  end

  context 'put' do
    it 'should send put requests with parameters and headers' do
      client = Itrp::Client.new(api_token: 'secret', max_retry_time: -1)
      stub = stub_request(:put, 'https://secret:@api.itrp.com/v1/people/1').with(body: {name: 'New Name'}, headers: {'X-ITRP-Custom' => 'custom'}).to_return(body: {id: 1}.to_json)
      response = client.put('people/1', {name: 'New Name'}, {'X-ITRP-Custom' => 'custom'})
      stub.should have_been_requested
    end
  end

  context 'post' do
    it 'should send post requests with parameters and headers' do
      client = Itrp::Client.new(api_token: 'secret', max_retry_time: -1)
      stub = stub_request(:post, 'https://secret:@api.itrp.com/v1/people').with(body: {name: 'New Name'}, headers: {'X-ITRP-Custom' => 'custom'}).to_return(body: {id: 101}.to_json)
      response = client.post('people', {name: 'New Name'}, {'X-ITRP-Custom' => 'custom'})
      stub.should have_been_requested
    end
  end

  context 'attachments' do
    before(:each) do
      @client = Itrp::Client.new(api_token: 'secret', max_retry_time: -1)
    end

    it 'should not log an error for XML responses' do
      xml = %(<?xml version="1.0" encoding="UTF-8"?>\n<details>some info</details>)
      stub_request(:get, 'https://secret:@api.itrp.com/v1/me').to_return(body: xml)
      expect_log('Sending GET request to api.itrp.com:443/v1/me', :debug)
      expect_log("XML response:\n#{xml}", :debug)
      response = @client.get('me')
      response.valid?.should == false
      response.raw.body.should == xml
    end

    it 'should not log an error for redirects' do
      stub_request(:get, 'https://secret:@api.itrp.com/v1/me').to_return(body: '', status: 303, headers: {'Location' => 'http://redirect.example.com/to/here'})
      expect_log('Sending GET request to api.itrp.com:443/v1/me', :debug)
      expect_log('Redirect: http://redirect.example.com/to/here', :debug)
      response = @client.get('me')
      response.valid?.should == false
      response.raw.body.should == nil
    end

    it "should not parse attachments for get requests" do
      expect(Itrp::Attachments).not_to receive(:new)
      stub_request(:get, 'https://secret:@api.itrp.com/v1/requests/777?attachments=/tmp/first.png,/tmp/second.zip&note=note').to_return(body: {id: 777, upload_called: false}.to_json)

      response = @client.get('/requests/777', {note: 'note', attachments: ['/tmp/first.png', '/tmp/second.zip'] })
      response.valid?.should == true
      response[:upload_called].should == false
    end

    [:post, :put].each do |method|
      it "should parse attachments for #{method} requests" do
        attachments = double('Itrp::Attachments')
        expect(attachments).to receive(:upload_attachments!) do |path, data|
          expect(path).to eq '/requests/777'
          expect(data[:attachments]).to eq ['/tmp/first.png', '/tmp/second.zip']
          data.delete(:attachments)
          data[:note_attachments] = 'processed'
        end
        expect(Itrp::Attachments).to receive(:new).with(@client){ attachments }
        stub_request(method, 'https://secret:@api.itrp.com/v1/requests/777').with(body: {note: 'note', note_attachments: 'processed' }).to_return(body: {id: 777, upload_called: true}.to_json)

        response = @client.send(method, '/requests/777', {note: 'note', attachments: ['/tmp/first.png', '/tmp/second.zip'] })
        response.valid?.should == true
        response[:upload_called].should == true
      end
    end

  end

  context 'import' do
    before(:each) do
      @client = Itrp::Client.new(api_token: 'secret', max_retry_time: -1)
      @multi_part_body = "--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"type\"\r\n\r\npeople\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"file\"; filename=\"#{@fixture_dir}/people.csv\"\r\nContent-Type: text/csv\r\n\r\nPrimary Email,Name\nchess.cole@example.com,Chess Cole\ned.turner@example.com,Ed Turner\r\n--0123456789ABLEWASIEREISAWELBA9876543210--"
      @multi_part_headers = {'Accept'=>'*/*', 'Content-Type'=>'multipart/form-data; boundary=0123456789ABLEWASIEREISAWELBA9876543210', 'User-Agent'=>'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/523.10.6 (KHTML, like Gecko) Version/3.0.4 Safari/523.10.6'}

      @import_queued_response = {body: {state: 'queued'}.to_json}
      @import_processing_response = {body: {state: 'processing'}.to_json}
      @import_done_response = {body: {state: 'done', results: {errors: 0, updated: 1, created: 1, failures: 0, unchanged: 0, deleted: 0}}.to_json}
      @import_failed_response = {body: {state: 'error', message: 'Invalid byte sequence in UTF-8 on line 2', results: {errors: 1, updated: 1, created: 0, failures: 1, unchanged: 0, deleted: 0}}.to_json}
      @server_failed_response = {body: {state: 'error', message: 'Invalid byte sequence in UTF-8 on line 2', results: {errors: 1, updated: 1, created: 0, failures: 1, unchanged: 0, deleted: 0}}.to_json}
      allow(@client).to receive(:sleep)
    end

    it 'should import a CSV file' do
      stub_request(:post, 'https://secret:@api.itrp.com/v1/import').with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: {token: '68ef5ef0f64c0'}.to_json)
      expect_log("Import file '#{@fixture_dir}/people.csv' successfully uploaded with token '68ef5ef0f64c0'.")

      response = @client.import(File.new("#{@fixture_dir}/people.csv"), 'people')
      response[:token].should == '68ef5ef0f64c0'
    end

    it 'should import a CSV file by filename' do
      stub_request(:post, 'https://secret:@api.itrp.com/v1/import').with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: {token: '68ef5ef0f64c0'}.to_json)
      response = @client.import("#{@fixture_dir}/people.csv", 'people')
      response[:token].should == '68ef5ef0f64c0'
    end

    it 'should wait for the import to complete' do
      stub_request(:post, 'https://secret:@api.itrp.com/v1/import').with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: {token: '68ef5ef0f64c0'}.to_json)
      progress_stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/import/68ef5ef0f64c0').to_return(@import_queued_response, @import_processing_response, @import_done_response)

      # verify the correct log statement are made
      expect_log('Sending POST request to api.itrp.com:443/v1/import', :debug)
      expect_log("Response:\n{\n  \"token\": \"68ef5ef0f64c0\"\n}", :debug)
      expect_log("Import file '#{@fixture_dir}/people.csv' successfully uploaded with token '68ef5ef0f64c0'.")
      expect_log('Sending GET request to api.itrp.com:443/v1/import/68ef5ef0f64c0', :debug)
      expect_log("Response:\n{\n  \"state\": \"queued\"\n}", :debug)
      expect_log("Import of '#{@fixture_dir}/people.csv' is queued. Checking again in 30 seconds.", :debug)
      expect_log('Sending GET request to api.itrp.com:443/v1/import/68ef5ef0f64c0', :debug)
      expect_log("Response:\n{\n  \"state\": \"processing\"\n}", :debug)
      expect_log("Import of '#{@fixture_dir}/people.csv' is processing. Checking again in 30 seconds.", :debug)
      expect_log('Sending GET request to api.itrp.com:443/v1/import/68ef5ef0f64c0', :debug)
      expect_log("Response:\n{\n  \"state\": \"done\",\n  \"results\": {\n    \"errors\": 0,\n    \"updated\": 1,\n    \"created\": 1,\n    \"failures\": 0,\n    \"unchanged\": 0,\n    \"deleted\": 0\n  }\n}", :debug)

      response = @client.import("#{@fixture_dir}/people.csv", 'people', true)
      response[:state].should == 'done'
      response[:results][:updated].should == 1
      progress_stub.should have_been_requested.times(3)
    end

    it 'should wait for the import to fail' do
      stub_request(:post, 'https://secret:@api.itrp.com/v1/import').with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: {token: '68ef5ef0f64c0'}.to_json)
      progress_stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/import/68ef5ef0f64c0').to_return(@import_queued_response, @import_processing_response, @import_failed_response)

      expect{ @client.import("#{@fixture_dir}/people.csv", 'people', true) }.to raise_error(Itrp::Exception, "Unable to monitor progress for people import. Invalid byte sequence in UTF-8 on line 2")
      progress_stub.should have_been_requested.times(3)
    end

    it 'should not continue when there is an error connecting to ITRP' do
      stub_request(:post, 'https://secret:@api.itrp.com/v1/import').with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: {token: '68ef5ef0f64c0'}.to_json)
      progress_stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/import/68ef5ef0f64c0').to_return(@import_queued_response, @import_processing_response).then.to_raise(StandardError.new('network error'))

      expect{ @client.import("#{@fixture_dir}/people.csv", 'people', true) }.to raise_error(Itrp::Exception, "Unable to monitor progress for people import. 500: No Response from Server - network error for 'api.itrp.com:443/v1/import/68ef5ef0f64c0'")
      progress_stub.should have_been_requested.times(3)
    end

    it 'should return an invalid response in case waiting for progress is false' do
      stub_request(:post, 'https://secret:@api.itrp.com/v1/import').with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: {message: 'oops!'}.to_json)
      response = @client.import("#{@fixture_dir}/people.csv", 'people', false)
      response.valid?.should == false
      response.message.should == 'oops!'
    end

    it 'should raise an UploadFailed exception in case waiting for progress is true' do
      stub_request(:post, 'https://secret:@api.itrp.com/v1/import').with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: {message: 'oops!'}.to_json)
      expect{ @client.import("#{@fixture_dir}/people.csv", 'people', true) }.to raise_error(Itrp::UploadFailed, 'Failed to queue people import. oops!')
    end

  end


  context 'export' do
    before(:each) do
      @client = Itrp::Client.new(api_token: 'secret', max_retry_time: -1)

      @export_queued_response = {body: {state: 'queued'}.to_json}
      @export_processing_response = {body: {state: 'processing'}.to_json}
      @export_done_response = {body: {state: 'done', url: 'https://download.example.com/export.zip?AWSAccessKeyId=12345'}.to_json}
      allow(@client).to receive(:sleep)
    end

    it 'should export multiple types' do
      stub_request(:post, 'https://secret:@api.itrp.com/v1/export').with(body: {type: 'people,people_contact_details'}).to_return(body: {token: '68ef5ef0f64c0'}.to_json)
      expect_log("Export for 'people,people_contact_details' successfully queued with token '68ef5ef0f64c0'.")

      response = @client.export(['people', 'people_contact_details'])
      response[:token].should == '68ef5ef0f64c0'
    end

    it 'should indicate when nothing is exported' do
      stub_request(:post, 'https://secret:@api.itrp.com/v1/export').with(body: {type: 'people', from: '2012-03-30T23:00:00+00:00'}).to_return(status: 204)
      expect_log("No changed records for 'people' since 2012-03-30T23:00:00+00:00.")

      response = @client.export('people', DateTime.new(2012,03,30,23,00,00))
      response[:token].should == nil
    end

    it 'should export since a certain time' do
      stub_request(:post, 'https://secret:@api.itrp.com/v1/export').with(body: {type: 'people', from: '2012-03-30T23:00:00+00:00'}).to_return(body: {token: '68ef5ef0f64c0'}.to_json)
      expect_log("Export for 'people' successfully queued with token '68ef5ef0f64c0'.")

      response = @client.export('people', DateTime.new(2012,03,30,23,00,00))
      response[:token].should == '68ef5ef0f64c0'
    end

    it 'should wait for the export to complete' do
      stub_request(:post, 'https://secret:@api.itrp.com/v1/export').with(body: {type: 'people'}).to_return(body: {token: '68ef5ef0f64c0'}.to_json)
      progress_stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/export/68ef5ef0f64c0').to_return(@export_queued_response, @export_processing_response, @export_done_response)

      # verify the correct log statement are made
      expect_log('Sending POST request to api.itrp.com:443/v1/export', :debug)
      expect_log(%(Response:\n{\n  "token": "68ef5ef0f64c0"\n}), :debug)
      expect_log("Export for 'people' successfully queued with token '68ef5ef0f64c0'.")
      expect_log('Sending GET request to api.itrp.com:443/v1/export/68ef5ef0f64c0', :debug)
      expect_log(%(Response:\n{\n  "state": "queued"\n}), :debug)
      expect_log("Export of 'people' is queued. Checking again in 30 seconds.", :debug)
      expect_log('Sending GET request to api.itrp.com:443/v1/export/68ef5ef0f64c0', :debug)
      expect_log(%(Response:\n{\n  "state": "processing"\n}), :debug)
      expect_log("Export of 'people' is processing. Checking again in 30 seconds.", :debug)
      expect_log('Sending GET request to api.itrp.com:443/v1/export/68ef5ef0f64c0', :debug)
      expect_log(%(Response:\n{\n  "state": "done",\n  "url": "https://download.example.com/export.zip?AWSAccessKeyId=12345"\n}), :debug)

      response = @client.export('people', nil, true)
      response[:state].should == 'done'
      response[:url].should == 'https://download.example.com/export.zip?AWSAccessKeyId=12345'
      progress_stub.should have_been_requested.times(3)
    end

    it 'should not continue when there is an error connecting to ITRP' do
      stub_request(:post, 'https://secret:@api.itrp.com/v1/export').with(body: {type: 'people'}).to_return(body: {token: '68ef5ef0f64c0'}.to_json)
      progress_stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/export/68ef5ef0f64c0').to_return(@export_queued_response, @export_processing_response).then.to_raise(StandardError.new('network error'))

      expect{ @client.export('people', nil, true) }.to raise_error(Itrp::Exception, "Unable to monitor progress for 'people' export. 500: No Response from Server - network error for 'api.itrp.com:443/v1/export/68ef5ef0f64c0'")
      progress_stub.should have_been_requested.times(3)
    end

    it 'should return an invalid response in case waiting for progress is false' do
      stub_request(:post, 'https://secret:@api.itrp.com/v1/export').with(body: {type: 'people'}).to_return(body: {message: 'oops!'}.to_json)
      response = @client.export('people')
      response.valid?.should == false
      response.message.should == 'oops!'
    end

    it 'should raise an UploadFailed exception in case waiting for progress is true' do
      stub_request(:post, 'https://secret:@api.itrp.com/v1/export').with(body: {type: 'people'}).to_return(body: {message: 'oops!'}.to_json)
      expect{ @client.export('people', nil, true) }.to raise_error(Itrp::UploadFailed, "Failed to queue 'people' export. oops!")
    end

  end

  context 'retry' do
    it 'should not retry when max_retry_time = -1' do
      stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/me').to_raise(StandardError.new('network error'))
      expect_log('Sending GET request to api.itrp.com:443/v1/me', :debug )
      expect_log("Request failed: 500: No Response from Server - network error for 'api.itrp.com:443/v1/me'", :error)

      client = Itrp::Client.new(api_token: 'secret', max_retry_time: -1)
      response = client.get('me')
      stub.should have_been_requested.times(1)
      response.valid?.should == false
      response.message.should == "500: No Response from Server - network error for 'api.itrp.com:443/v1/me'"
    end

    it 'should not retry 4 times when max_retry_time = 16' do
      stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/me').to_raise(StandardError.new('network error'))
      [2,4,8,16].each_with_index do |secs, i|
        expect_log('Sending GET request to api.itrp.com:443/v1/me', :debug )
        expect_log("Request failed, retry ##{i+1} in #{secs} seconds: 500: No Response from Server - network error for 'api.itrp.com:443/v1/me'", :warn)
      end

      client = Itrp::Client.new(api_token: 'secret', max_retry_time: 16)
      allow(client).to receive(:sleep)
      response = client.get('me')
      stub.should have_been_requested.times(4)
      response.valid?.should == false
      response.message.should == "500: No Response from Server - network error for 'api.itrp.com:443/v1/me'"
    end

    it 'should return the response after retry succeeds' do
      stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/me').to_raise(StandardError.new('network error')).then.to_return(body: {name: 'my name'}.to_json)
      expect_log('Sending GET request to api.itrp.com:443/v1/me', :debug )
      expect_log("Request failed, retry #1 in 2 seconds: 500: No Response from Server - network error for 'api.itrp.com:443/v1/me'", :warn)
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
      stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/me').to_return(status: 429, body: {message: 'Too Many Requests'}.to_json)
      expect_log('Sending GET request to api.itrp.com:443/v1/me', :debug )
      expect_log("Request failed: 429: Too Many Requests", :error)

      client = Itrp::Client.new(api_token: 'secret', block_at_rate_limit: false)
      response = client.get('me')
      stub.should have_been_requested.times(1)
      response.valid?.should == false
      response.message.should == '429: Too Many Requests'
    end

    it 'should block on rate limit when block_at_rate_limit is true' do
      stub = stub_request(:get, 'https://secret:@api.itrp.com/v1/me').to_return(status: 429, body: {message: 'Too Many Requests'}.to_json).then.to_return(body: {name: 'my name'}.to_json)
      expect_log('Sending GET request to api.itrp.com:443/v1/me', :debug )
      expect_log('Request throttled, trying again in 5 minutes: 429: Too Many Requests', :warn)
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
