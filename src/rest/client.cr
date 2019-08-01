# TODO: own request/response type to avoid exposing stdlib and consuming
#   the Request object's body IO. think about attachements? maybe we foot
#   it and deal with it in memory.

module Cryogonal::REST
  # The base URI at which all API requests are made. Note that this can,
  # if necessary, be mutated to point at other hosts.
  BASE_URI = URI.parse("https://discordapp.com")

  # Required user agent to make requests.
  USER_AGENT = "DiscordBot (https://github.com/z64/cryogonal, #{Cryogonal::VERSION}) Crystal #{Crystal::VERSION}"

  # SSL context to be shared between requests. This saves re-negotiating SSL
  # details with each request.
  SSL_CONTEXT = OpenSSL::SSL::Context::Client.new

  # Maximum amount of times to retry a request that returned an error we expect
  # to be transient (429 Too Many Requests, 502 Bad Gateway)
  MAX_ATTEMPTS = 5

  # Interface to the REST API. Requires a `Token` for authorization, and a
  # `LimitStore` to store rate limiting information returned from the API.
  # The client will query and update the limit storage, and use it for
  # automatic rate limit handling.
  struct Client
    # The name of this client to show in logging.
    property name

    def initialize(@token : Token, @logger : Logger = Cryogonal::LOGGER)
      @name = "[HTTP]"
      @limit_table = LimitTable.new
    end

    # Uses this client to execute the given HTTP request. The key will be used
    # to identify the rate limit bucket that this request should fall under.
    # If a request *would* incur a rate limit, execution will wait until that
    # rate limit has expired before executing it.
    def send(request : HTTP::Request, key : LimitKey)
      connection = HTTP::Client.new(BASE_URI, tls: SSL_CONTEXT)
      trace = rand(UInt32::MAX).to_s(16).rjust(8, '0')
      send_internal(request, key, connection, 1, trace)
    ensure
      connection.try(&.close)
    end

    private def send_internal(request : HTTP::Request, key : LimitKey, connection : HTTP::Client,
                              attempt_number : Int32, trace : String)
      @limit_table.get_by_key(key).try do |bucket|
        if waited = bucket.wait
          @logger.debug { "#{@name} #{trace} | #{key} Waited #{waited} to acquire bucket" }
        end

        if bucket.next_will_limit
          @logger.info("#{@name} #{trace} | #{key} Locked")
          bucket.cooldown
          @logger.info("#{@name} #{trace} | #{key} Released")
        end
      end

      request.headers.tap do |h|
        unless @token.type.empty?
          h["Authorization"] = @token.to_s
        end
        h["User-Agent"] = USER_AGENT
        h["Connection"] = "Keep-Alive"
      end

      @logger.info("#{@name} #{trace} | #{request.method} #{request.path}#{request.query}")
      connection ||= HTTP::Client.new(BASE_URI, tls: SSL_CONTEXT)
      response = connection.exec(request)
      status = response.status
      @logger.info("#{@name} #{trace} | #{status.code} #{status.description}")
      @limit_table.update(key, response.headers)

      case status
      when .success?
        response
      when .too_many_requests?, .bad_gateway?
        if attempt_number >= MAX_ATTEMPTS
          # TODO: error class
          raise "Max request attempts exceeded"
        end
        request.body.try(&.rewind)
        send_internal(request, key, connection, attempt_number + 1, trace)
      when .client_error?
        # TODO: error parsing & class
        raise "Request failed: #{response.body? || "(no body)"}"
      end
    end
  end
end
