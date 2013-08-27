%w(net/http json uri date time net/https open-uri itrp).each{ |f| require f }
%w(version response multipart core_ext).each{ |f| require "itrp/client/#{f}" }

module Itrp
  class Client
    MAX_PAGE_SIZE = 100
    DEFAULT_HEADER = {'Content-Type' => 'application/json'}

    # Create a new ITRP Client
    #
    # Shared configuration for all ITRP Clients:
    # Itrp.configure do |config|
    #   config.api_token = 'd41f5868feb65fc87fa2311a473a8766ea38bc40'
    #   config.account = 'my-sandbox'
    #   ...
    # end
    #
    # Override configuration per ITRP Client:
    # itrp = Itrp::Client.new(account: 'trusted-sandbox')
    #
    # All options available:
    #  - logger:      The Ruby Logger instance, default: Logger.new(STDOUT)
    #  - host:        The ITRP API host, default: 'https://api.itrp.com'
    #  - api_version: The ITRP API version, default: 'v1'
    #  - api_token:   *required* The ITRP API token
    #  - account:     Specify a different (trusted) account to work with
    #                 @see http://developer.itrp.com/v1/#multiple-accounts
    #  - source:      The Source used when creating new records
    #                 @see http://developer.itrp.com/v1/general/source/
    #
    #  - max_retry_time: maximum nr of seconds to wait for server to respond (default = 5400 = 1.5 hours)
    #                    the sleep time between retries starts at 2 seconds and doubles after each retry
    #                    retry times: 2, 6, 18, 54, 162, 486, 1458, 4374, 13122, ... seconds
    #                    one retry will always be performed unless you set the value to -1
    #  - read_timeout:   HTTP GET read timeout in seconds (default = 60)
    #  - block_at_rate_limit: Set to +true+ to block the request until the rate limit is lifted, default: +false+
    #                         @see http://developer.itrp.com/v1/#rate-limiting
    #
    #  - proxy_host:     Define in case HTTP traffic needs to go through a proxy
    #  - proxy_port:     Port of the proxy, defaults to 8080
    #  - proxy_user:     Proxy user
    #  - proxy_password: Proxy password
    def initialize(options = {})
      @options = Itrp.configuration.current.merge(options)
      [:host, :api_version, :api_token].each do |required_option|
        raise ::Itrp::Exception.new("Missing required configuration option #{required_option}") if option(required_option).blank?
      end
      host = option(:host)
      @ssl = !!(host =~ /^https/)
      host = host.gsub(/https?:\/\//, '')
      @domain, @port = host =~ /^(.*):(\d+)$/ ? [$1, $2.to_i] : [host, @ssl ? 443 : 80]
      @logger = @options[:logger]
    end

    # Retrieve an option
    def option(key)
      @options[key]
    end

    # Yield all retrieved resources one-by-one for the given (paged) API query.
    # Blocks (!) when the Rate Limit is exceeded, see http://developer.itrp.com/v1/#rate-limiting
    # Raises an ::Itrp::Exception with the message from ITRP when anything else fails
    # Returns total nr of resources yielded (handy for logging)
    def each(path, params = {}, &block)
      # retrieve the resources using the max page size (least nr of API calls)
      next_path = expand_path(path, {:per_page => MAX_PAGE_SIZE, :page => 1}.merge(params))
      size = 0
      while next_path
        # retrieve the records (with retry and optionally wait for rate-limit)
        response = get(next_path)
        # raise exception in case the response is invalid
        raise ::Itrp::Exception.new(response.message) unless response.valid?
        # yield the resources
        response.json.each{ |resource| yield resource }
        size += response.json.size
        # go to the next page
        next_path = response.pagination_relative_link(:next)
      end
      size
    end

    # send HTTPS GET request and return instance of Itrp::Response
    def get(path, params = {}, header = {})
      _send(Net::HTTP::Get.new(expand_path(path, params), expand_header(header)))
    end

    # send HTTPS PUT request and return instance of Itrp::Response
    def put(path, data = {}, header = {})
      _send(json_request(Net::HTTP::Put, path, data, header))
    end

    # send HTTPS POST request and return instance of Itrp::Response
    def post(path, data = {}, header = {})
      _send(json_request(Net::HTTP::Post, path, data, header))
    end

    # upload a CSV file to import
    # @param csv: The CSV File or the location of the CSV file
    # @param type: The type, e.g. person, organization, people_contact_details
    def import(csv, type, block_until_completed = false)
      csv = File.open(csv, 'r') unless cvs.respond_to?(:path) && cvs.respond_to?(:read)
      data, headers = Itrp::Multipart::Post.prepare_query('type' => type, 'file' => csv)
      request = Net::HTTP::Post.new(expand_path('/import'), expand_header(headers))
      request.body = data
      response = _send(request)

      if block_until_completed && response.valid?
        token = response[:token]
        while true
          response = get("/import/#{token}")
          # wait if the response is OK and import is still busy
          break unless response.valid? && response[:state].in?(['queued', 'processing'])
        end
      end

      response
    end

    private

    # create a request (place data in body if the request becomes too large)
    def json_request(request_class, path, data = {}, header = {})
      request = request_class.new(expand_path(path), expand_header(header))
      body = {}
      data.each{ |k,v| body[k.to_s] = typecast(v, false) }
      request.body = body.to_json
      request
    end

    URI_ESCAPE_PATTERN = Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")
    def uri_escape(value)
      URI.escape(value, URI_ESCAPE_PATTERN).gsub('.', '%2E')
    end

    # Expand the given header with the default header
    def expand_header(header = {})
      header = DEFAULT_HEADER.merge(header)
      header['X-ITRP-Account'] = option(:account) if option(:account)
      header['AUTHORIZATION'] = 'Basic ' + ["#{option(:api_token)}:"].pack("m*")
      if option(:source)
        header['X-ITRP-Source'] = option(:source)
        header['HTTP_USER_AGENT'] = option(:source)
      end
      header
    end

    # Expand the given path with the parameters
    # Examples:
    #   :person_id => 5
    #   :"updated_at=>" => yesterday
    #   :fields => ["id", "created_at", "sourceID"]
    def expand_path(path, params = {})
      path = path.dup
      path = "/#{path}" unless path =~ /^\// # make sure path starts with /
      path = "/#{option(:api_version)}#{path}" unless path =~ /^\/v[\d.]+\// # preprend api version
      params.each do |key, value|
        path << (path['?'] ? '&' : '?')
        path << expand_param(key, value)
      end
      path
    end

    # Expand one parameter, e.g. (:"created_at=>", DateTime.now) to "created_at=%3E22011-12-16T12:24:41+01:00"
    def expand_param(key, value)
      param = uri_escape(key.to_s).gsub('%3D', '=') # handle :"updated_at=>" or :"person_id!=" parameters
      param << '=' unless key['=']
      param << typecast(value)
      param
    end

    # Parameter value typecasting
    def typecast(value, escape = true)
      case value.class.name.to_sym
        when :NilClass    then ''
        when :String      then escape ? URI.escape(value) : value
        when :TrueClass   then 'true'
        when :FalseClass  then 'false'
        when :DateTime    then value.new_offset(0).iso8601
        when :Date        then value.strftime("%Y-%m-%d")
        when :Time        then value.strftime("%H:%M")
        when :Array       then value.map{ |v| typecast(v, escape) }.join(',')
        else value.to_s
      end
    end

    # Send a request to ITRP and wrap the HTTP Response in an Itrp::Response
    # Guaranteed to return a Response, thought it may be +empty?+
    def _send(request)
      @logger.debug { "Sending #{request.method} request to #{@domain}:#{@port}#{request.path}" }
      _response = begin
        http_with_proxy = option(:proxy_host).blank? ? Net::HTTP : Net::HTTP::Proxy(option(:proxy_host), option(:proxy_port), option(:proxy_user), option(:proxy_password))
        http = http_with_proxy.new(@domain, @port)
        http.read_timeout = option(:read_timeout)
        http.use_ssl = @ssl
        http.start{ |_http| _http.request(request) }
      rescue ::Exception => e
        Struct.new(:body, :message, :code, :header).new(nil, "No Response from Server - #{e.message} for '#{@domain}:#{@port}#{request.path}'", 500, {})
      end
      response = Itrp::Response.new(request, _response)
      if response.valid?
        @logger.debug { "Response:\n#{JSON.pretty_generate(response.json)}" }
      else
        @logger.error { "Request failed: #{response.message}" }
      end
      response
    end

    # Wraps the _send method with retries when the server does not responsd, see +initialize+ option +:rate_limit_block+
    def _send_with_rate_limit_block(request)
      return _send_without_rate_limit_block(request) unless option(:block_at_rate_limit)
      now = Time.now
      begin
        _response = _send_without_rate_limit_block(request)
        @logger.warn { "Request throttled, trying again in 5 minutes: #{_response.message}" } and sleep(300) if _response.throttled?
      end while _response.throttled? && (Time.now - now) < 3660 # max 1 hour and 1 minute
      _response
    end
    alias_method_chain :_send, :rate_limit_block

    # Wraps the _send method with retries when the server does not responsd, see +initialize+ option +:retries+
    def _send_with_retries(request)
      retries = 0
      sleep_time = 2
      total_retry_time = 0
      begin
        _response = _send_without_retries(request)
        @logger.warn { "Request failed, retry ##{retries += 1} in #{sleep_time} seconds: #{_response.message}" } and sleep(sleep_time) if _response.empty? && option(:max_retry_time) > 0
        total_retry_time += sleep_time
        sleep_time *= 2
      end while _response.empty? && total_retry_time < option(:max_retry_time)
      _response
    end
    alias_method_chain :_send, :retries

  end
end

# HTTPS with certificate bundle
module Net
  class HTTP
    alias_method :original_use_ssl=, :use_ssl=

    def use_ssl=(flag)
      self.ca_file = File.expand_path("../ca-bundle.crt", __FILE__) if flag
      self.verify_mode = OpenSSL::SSL::VERIFY_PEER
      self.original_use_ssl = flag
    end
  end
end

