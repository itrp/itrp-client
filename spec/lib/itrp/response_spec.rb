require 'spec_helper'

describe Itrp::Response do
  before(:each) do
    @client = Itrp::Client.new(api_token: 'secret', max_retry_time: -1)
    @person_hash = {
        addresses:[],
        contacts:[ {id: 1365, label: 'work', telephone: '7139872946'} ],
        id: 562,
        information: 'Info about John.',
        job_title: 'rolling stone',
        locale: 'en-US',
        location: 'Top of John Hill',
        name: 'John',
        organization: {id: 20, name: 'ITRP Institute'},
        picture_uri: nil,
        primary_email: 'john@example.com',
        site: {id:14, name: 'IT Training Facility'},
        time_format_24h: false,
        time_zone: 'Central Time (US & Canada)'
    }
    stub_request(:get, 'https://secret:@api.itrp.com/v1/me').to_return(:body => @person_hash.to_json)
    @response_hash = @client.get('me')

    @client = Itrp::Client.new(api_token: 'secret', max_retry_time: -1)
    @people_array = [
        {id: 562, name: 'John', organization: { id: 20, name: 'ITRP Institute'}, site: {id: 14, name: 'IT Training Facility'} },
        {id: 560, name: 'Lucas', organization: { id: 20, name: 'ITRP Institute', office: { name: 'The Office'}}, site: {id: 14, name: 'IT Training Facility'} },
        {id: 561, name: 'Sheryl', organization: { id: 20, name: 'ITRP Institute'}, site: {id: 14, name: 'IT Training Facility'} }
    ]
    stub_request(:get, 'https://secret:@api.itrp.com/v1/people').to_return(:body => @people_array.to_json)
    @response_array = @client.get('people')
  end

  it 'should contain the request' do
    @response_hash.request.class.name.should == 'Net::HTTP::Get'
    @response_hash.request.path.should == '/v1/me'
  end

  it 'should contain the full request' do
    @response_hash.response.class.name.should == 'Net::HTTPOK'
    @response_hash.response.should respond_to(:body)
  end

  it 'should provide easy access to the body' do
    @response_hash.body.should include(%("primary_email":"john@example.com"))
  end

  context 'json/message' do
    it 'should provide the JSON value for single records' do
      be_json_eql(@response_hash.json, @person_hash)
    end

    it 'should provide the JSON value for lists' do
      be_json_eql(@response_array.json, @people_array)
    end

    it 'should provide indifferent access for single records' do
      @response_hash.json['organization']['name'].should == 'ITRP Institute'
      @response_hash.json[:organization][:name].should == 'ITRP Institute'
      @response_hash.json[:organization]['name'].should == 'ITRP Institute'
      @response_hash.json['organization'][:name].should == 'ITRP Institute'
    end

    it 'should provide indifferent access for lists' do
      @response_array.json.first['site']['name'].should == 'IT Training Facility'
      @response_array.json.first[:site][:name].should == 'IT Training Facility'
      @response_array.json.last[:site]['name'].should == 'IT Training Facility'
      @response_array.json.last['site'][:name].should == 'IT Training Facility'
    end

    it 'should add a message if the body is empty' do
      stub_request(:get, 'https://secret:@api.itrp.com/v1/organizations').to_return(:status => 429, :body => nil)
      response = @client.get('organizations')

      message = '429: empty body'
      response.json[:message].should == message
      response.json['message'].should == message
      response.message.should == message
    end

    it 'should add a message if the HTTP response is not OK' do
      stub_request(:get, 'https://secret:@api.itrp.com/v1/organizations').to_return(:status => 429, :body => {message: 'Too Many Requests'}.to_json)
      response = @client.get('organizations')

      message = '429: Too Many Requests'
      response.json[:message].should == message
      response.json['message'].should == message
      response.message.should == message
    end

    it 'should add a message if the JSON body cannot be parsed' do
      stub_request(:get, 'https://secret:@api.itrp.com/v1/organizations').to_return(:body => '==$$!invalid')
      response = @client.get('organizations')

      message = "Invalid JSON - 746: unexpected token at '==$$!invalid' for:\n#{response.body}"
      response.json[:message].should == message
      response.json['message'].should == message
      response.message.should == message
    end

    it 'should have a blank message when single record is succesfully retrieved' do
      @response_hash.message.should == nil
    end

    it 'should have a blank message when single record is succesfully retrieved' do
      @response_array.message.should == nil
    end

  end

  it 'should define empty' do
    stub_request(:get, 'https://secret:@api.itrp.com/v1/organizations').to_return(:status => 429, :body => nil)
    response = @client.get('organizations')

    response.empty?.should == true
    @person_hash.empty?.should == false
    @people_array.empty?.should == false
  end

  context 'valid' do
    it 'should be valid when the message is nil' do
      expect(@response_hash).to receive(:message){ nil }
      @response_hash.valid?.should == true
    end

    it 'should not be valid when the message is not nil' do
      expect(@response_array).to receive(:message){ 'invalid' }
      @response_array.valid?.should == false
    end
  end

  context '[] access' do
    context 'single records' do
      it 'should delegate [] to the json' do
        @response_hash[:name].should == 'John'
      end

      it 'should allow multiple keys' do
        @response_hash[:organization, 'name'].should == 'ITRP Institute'
      end

      it 'should allow nils when using multiple keys' do
        @response_hash[:organization, :missing, 'name'].should == nil
      end
    end

    context 'list of records' do
      it 'should delegate [] to the json of each record' do
        @response_array['name'].should == ['John', 'Lucas', 'Sheryl']
      end

      it 'should allow multiple keys' do
        @response_array[:organization, 'name'].should == ['ITRP Institute', 'ITRP Institute', 'ITRP Institute']
      end

      it 'should allow nils when using multiple keys' do
        @response_array[:organization, :office, 'name'].should == [nil, 'The Office', nil]
      end
    end
  end

  context 'size' do
    it 'should return 1 for single records' do
      @response_hash.size.should == 1
    end

    it 'should return the array size for list records' do
      @response_array.size.should == 3
    end

    it 'should return nil if an error message is present' do
      expect(@response_hash).to receive(:message){ 'error message' }
      @response_hash.size.should == 0
    end
  end

  context 'count' do
    it 'should return 1 for single records' do
      @response_hash.count.should == 1
    end

    it 'should return the array size for list records' do
      @response_array.count.should == 3
    end

    it 'should return nil if an error message is present' do
      expect(@response_hash).to receive(:message){ 'error message' }
      @response_hash.count.should == 0
    end
  end

  context 'pagination' do
    before(:each) do
      @pagination_header = {
          'X-Pagination-Per-Page' => 3,
          'X-Pagination-Current-Page' => 1,
          'X-Pagination-Total-Pages' => 2,
          'X-Pagination-Total-Entries' => 5,
          'Link' => '<https://api.itrp.com/v1/people?page=1&per_page=3>; rel="first",<https://api.itrp.com/v1/people?page=2&per_page=3>; rel="next", <https://api.itrp.com/v1/people?page=2&per_page=3>; rel="last"',
      }
      allow(@response_array.response).to receive('header'){ @pagination_header }
    end

    it "should retrieve per_page from the 'X-Pagination-Per-Page' header" do
      @response_array.per_page.should == 3
    end

    it "should retrieve current_page from the 'X-Pagination-Current-Page' header" do
      @response_array.current_page.should == 1
    end

    it "should retrieve total_pages from the 'X-Pagination-Total-Pages' header" do
      @response_array.total_pages.should == 2
    end

    it "should retrieve total_entries from the 'X-Pagination-Total-Entries' header" do
      @response_array.total_entries.should == 5
    end

    {first: 'https://api.itrp.com/v1/people?page=1&per_page=3',
     next: 'https://api.itrp.com/v1/people?page=2&per_page=3',
     last: 'https://api.itrp.com/v1/people?page=2&per_page=3'}.each do |relation, link|

      it "should define pagination link for :#{relation}" do
        @response_array.pagination_link(relation).should == link
      end
    end

    {first: '/v1/people?page=1&per_page=3',
     next: '/v1/people?page=2&per_page=3',
     last: '/v1/people?page=2&per_page=3'}.each do |relation, link|

      it "should define pagination relative link for :#{relation}" do
        @response_array.pagination_relative_link(relation).should == link
      end
    end
  end

  context 'throttled?' do
    it 'should not be trhottled by default' do
      @response_hash.throttled?.should == false
      @response_array.throttled?.should == false
    end

    it 'should check the return code' do
      stub_request(:get, 'https://secret:@api.itrp.com/v1/organizations').to_return(:status => 429, :body => nil)
      response = @client.get('organizations')
      response.throttled?.should == true
    end

    it 'should check the return message' do
      stub_request(:get, 'https://secret:@api.itrp.com/v1/organizations').to_return(:status => 500, :body => {message: 'Too Many Requests'} )
      response = @client.get('organizations')
      response.throttled?.should == true
    end
  end

  context 'to_s' do
    it 'should return the JSON as a string' do
      @response_hash.to_s.should == JSON.parse(@person_hash.to_json).to_s
    end

    it 'should return the message in case the response is not valid' do
      stub_request(:get, 'https://secret:@api.itrp.com/v1/organizations').to_return(:status => 429, :body => nil)
      response = @client.get('organizations')
      response.to_s.should == '429: empty body'
    end
  end

end
