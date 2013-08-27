module Itrp
  class Response
    def initialize(request, response)
      @request = request
      @response = response
    end

    def request
      @request
    end

    def response
      @response
    end

    def body
      @response.body
    end

    # The JSON value, if single resource is queried this is a Hash, if multiple resources where queried it is an Array
    # If the response is not +valid?+ it is a Hash with 'message' and optionally 'errors'
    def json
      @json ||= begin
        JSON.parse(@response.body)
      rescue ::Exception => e
        { 'message' => @response.is_a?(Net::HTTPSuccess) ? "Invalid JSON - #{e.message} for:\n#{@response.body}" : @response.body.nil? ? @response.message : @response.body }
      end
    end

    # The nr of resources found
    def size
      @size ||= message ? 0 : json.is_a?(Array) ? json.size : 1
    end
    alias :count :size

    # retrieve a value from the resource
    # if the JSON value is an Array a array with the value for each resource will be given
    # @param keys: a single key or a key-path seperated by comma
    def[](*keys)
      values = json.is_a?(Array) ? json : [json]
      keys.each { |key| values = values.map{ |value| value.is_a?(Hash) ? value[key.to_s] : nil} }
      json.is_a?(Array) ? values : values.first
    end

    # +true+ if no 'message' is given (and the JSON could be parsed)
    def valid?
      message.nil?
    end

    # the error message in case the response is not +valid?+
    def message
      @message ||= @response.is_a?(Net::HTTPSuccess) ? nil : json.is_a?(Hash) ? json['message'] : "#{@response.code}: #{@response.message}"
    end

    # pagination - per page
    def per_page
      @per_page ||= @response.header['X-Pagination-Per-Page'].to_i
    end

    # pagination - current page
    def current_page
      @current_page ||= @response.header['X-Pagination-Current-Page'].to_i
    end

    # pagination - total pages
    def total_pages
      @total_pages ||= @response.header['X-Pagination-Total-Page'].to_i
    end

    # pagination - total entries
    def total_entries
      @total_entries ||= @response.header['X-Pagination-Total-Entries'].to_i
    end

    # pagination urls (full paths with server) - relations :first, :prev, :next, :last
    # Link: <https://api.itrp.com/v1/requests?page=1&per_page=25>; rel="first", <https://api.itrp.com/v1/requests?page=2&per_page=25>; rel="prev", etc.
    def pagination_link(relation)
      # split on ',' select the [url] in '<[url]>; rel="[relation]"', compact to all url's found (at most one) and take the first
      (@pagination_links ||= {})[relation] ||= @response.header['Link'] && @response.header['Link'].split(/,\s*<?/).map{ |link| link[/^\s*<?(.*?)>?;\s*rel="#{relation.to_s}"\s*$/, 1] }.compact.first
    end

    # pagination urls (relative paths without server) - relations :first, :prev, :next, :last
    def pagination_relative_link(relation)
      (@pagination_relative_links ||= {})[relation] ||= pagination_link(relation) && pagination_link(relation)[/^https?:\/\/[^\/]*(.*)/, 1]
    end

    # +true+ if the response is invalid because of throttling
    def throttled?
      @response.code.to_s == '429' || (message && message =~ /Too Many Requests/)
    end

    # +true+ if the server did not respond at all
    def empty?
      @response.body.nil?
    end

    def to_s
      valid? ? json.to_s : "#{@response.code}: #{message}"
    end

  end
end
