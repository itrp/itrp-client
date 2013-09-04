# Itrp::Client

Client for accessing the ITRP REST API

## Installation

Add this line to your application's Gemfile:

    gem 'itrp-client'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install itrp-client

## Usage

### Configuration

```
Itrp.configure do |config|
  config.api_token = 'd41f5868feb65fc87fa2311a473a8766ea38bc40'
  config.account = 'my-sandbox'
  config.logger = Rails.logger
  ...
end
```

All options available:
* logger:      The Ruby Logger instance, default: Logger.new(STDOUT)
* host:        The ITRP API host, default: 'https://api.itrp.com'
* api_version: The ITRP API version, default: 'v1'
* api_token:   *required* The ITRP API token
* account:     Specify a different (trusted) account to work with
               @see http://developer.itrp.com/v1/#multiple-accounts
* source:      The Source used when creating new records
               @see http://developer.itrp.com/v1/general/source/

* max_retry_time: maximum nr of seconds to wait for server to respond (default = 5400 = 1.5 hours)
                  the sleep time between retries starts at 2 seconds and doubles after each retry
                  retry times: 2, 6, 18, 54, 162, 486, 1458, 4374, 13122, ... seconds
                  one retry will always be performed unless you set the value to -1
* read_timeout:   HTTP GET read timeout in seconds (default = 25)
* block_at_rate_limit: Set to +true+ to block the request until the rate limit is lifted, default: +false+
                       @see http://developer.itrp.com/v1/#rate-limiting

* proxy_host:     Define in case HTTP traffic needs to go through a proxy
* proxy_port:     Port of the proxy, defaults to 8080
* proxy_user:     Proxy user
* proxy_password: Proxy password

### ITRP Client

```
client = Itrp::Client.new
response = client.get('me')
puts response[:primary_email]
```

Override global configuration per client:

```
client = Itrp::Client.new(:account => 'trusted-sandbox')
response = client.get('people/20')
puts response[:primary_email]
```

TODO: More documentation (each, put, post, import, response metadata)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
