module Cryogonal::Gateway
  # Low level, *stateless* connection interface to the gateway. It holds the
  # websocket connection to the gateway, and exposes methods to receive packets
  # and send commands within Discord's gateway protocol.
  #
  # Example usage:
  # ```
  # shard = Cryogonal::Gateway::Shard.new
  # spawn(shard.connect("wss://gateway.discord.gg?v=6"))
  #
  # while ws_event = shard.receive
  #   case message
  #   when Cryogonal::Gateway::Connected
  #     # ..
  #   when Cryogonal::Gateway::Packet
  #     # ..
  #   when Cryogonal::Gateway::Close
  #     # ..
  #   end
  # end
  # ```
  #
  # NOTE: The gateway URI in the above example is for illustration only. The
  #   active gateway URI should be obtained from the HTTP API via
  #   `REST#get_gateway_bot`.
  struct Shard
    # The name of this shard to show in logging.
    property name

    @ws : HTTP::WebSocket?

    def initialize(@logger : Logger = Cryogonal::LOGGER)
      @name = "[Shard]"
      @channel = Channel(Event).new
    end

    # Connects to the passed gateway URI and starts listening for incoming
    # packets. You can then process these events using `Shard#receive`. Options
    # for selecting gateway version and transport compression should be set
    # on the query component of this URI.
    #
    # NOTE: This occurs in the current fiber. You can place the connection
    #   fiber in the background by simply doing `spawn(shard.connect(..))`.
    def connect(gateway_uri : URI | String)
      gateway_uri = URI.parse(gateway_uri) if gateway_uri.is_a?(String)
      @logger.info("#{@name} Connecting to #{gateway_uri}")

      compressor = Compressor.get("zlib")
      decoder = Decoder.get("json")

      gateway_uri.query.try do |query|
        parsed = HTTP::Params.parse(query)

        case value = parsed["v"]?
        when "6", nil
          # OK
        else
          @logger.warn("#{@name} Unsupported gateway version requested: #{value}")
        end

        if value = parsed["compress"]?
          compressor = Compressor.get(value).try { |comp| compressor = comp }
        end

        if value = parsed["encoding"]?
          decoder = Decoder.get(value)
        end
      end

      ws = @ws = HTTP::WebSocket.new(gateway_uri)

      ws.on_message do |text|
        @logger.debug { "#{@name} WS frame in (text, #{text.bytesize} bytes)" }
        @logger.debug { "#{@name} #{text}" }
        packet = decoder.decode(text)
        @channel.send(packet)
      end

      ws.on_binary do |bytes|
        @logger.debug { "#{@name} WS frame in (binary, #{bytes.size} bytes)" }
        @logger.debug { "#{@name} Data:\n#{bytes.hexdump}" }
        if completed = compressor.read(bytes)
          packet = decoder.decode(completed)
          @channel.send(packet)
        end
      end

      ws.on_close do |data|
        @logger.debug { "#{@name} WS frame in (close frame, #{data.size} bytes)" }
        code = nil
        reason = nil

        unless data.empty?
          close = Close.new(data)
          @channel.send(close)
          code = close.code
          reason = close.reason
        end

        @logger.info("#{@name} Websocket closed with code: #{code || "none"}, reason: #{reason || "none"}")
      end

      @logger.info("#{@name} Connected")
      @channel.send(Connected.new)
      ws.run
    rescue ex
      @logger.error("#{@name} WS error: #{ex.inspect_with_backtrace}")
    ensure
      @ws.try do |ws|
        unless ws.closed?
          bytes = Bytes.new(sizeof(UInt16))
          IO::ByteFormat::NetworkEndian.encode(1000, bytes)
          ws.close(bytes)
        end
      end
      @logger.info("#{@name} Disconnected")
      @channel.send(Disconnected.new)
    end

    # Disconnects this shard from the gateway with the given close code.
    #
    # Raises if this shard is not connected yet. (See `Shard#connect`)
    def disconnect(code : UInt16 = 1000)
      bytes = Bytes.new(sizeof(UInt16))
      IO::ByteFormat::NetworkEndian.encode(code, bytes)
      @logger.info("#{name} Disconnecting with code #{code}")
      @ws.not_nil!.close(bytes)
    end

    # Identifies this shard on the gateway. This effectively authenticates
    # this shard and begins a *new* session. If you have a `SessionDescription`
    # from a previous session, you should try to use `Shard#resume` instead.
    #
    # Raises if this shard is not connected yet. (See `Shard#connect`)
    #
    # NOTE: You can identify one shard every 5 seconds, and 1000 times within
    #   24 hours. A successful identification will yield a `READY` dispatch
    #   event.
    #
    # TODO: Internal identify struct
    def identify(token : Token,
                 compress : Bool,
                 large_threshold : Int32,
                 shard : Tuple(Int32, Int32),
                 presence : Nil,
                 guild_subscriptions : Bool)
      token.bot_type!
      payload = {
        op: Opcode::Identify,
        d:  {
          token:      token.to_s,
          properties: {
            "$os":      "Linux",
            "$browser": "cryogonal",
            "$device":  "cryogonal",
          },
          compress:            compress,
          shard:               shard,
          guild_subscriptions: guild_subscriptions,
        },
      }.to_json
      @logger.info("#{@name} Identifying with #{token.inspect} @ #{shard}")
      @logger.debug { "#{@name} Sending: #{payload}" }
      @ws.not_nil!.send(payload)
    end

    # Resumes a previous session, typically used after the shard was
    # disconnected for any reason. If the resume is successful, then
    # events that occured while the shard was disconnected will be replayed.
    #
    # Raises if this shard is not connected yet. (See `Shard#connect`)
    def resume(token : Token, session : SessionDescription)
      raise "unimplemented"
    end

    # Sends a heartbeat payload, used to maintain an existing connection.
    # Heartbeats should be sent *within* the interval specified in `HELLO`
    # payloads, which is sent immediately after connecting. It is advised
    # to wait a random amount of time to "offset" into the heartbeat period
    # before sending a heartbeat every interval.
    #
    # ```
    # period_offset = rand(heartbeat_interval.total_seconds)
    # sleep(period_offset)
    # while true
    #   shard.heartbeat(session.sequence)
    #   sleep(heartbeat_interval)
    # end
    # ```
    #
    # Raises if this shard is not connected yet. (See `Shard#connect`)
    def heartbeat(sequence : Int64? = nil)
      payload = {
        op: Opcode::Heartbeat,
        d:  sequence,
      }.to_json
      @logger.debug { "#{@name} Sending: #{payload}" }
      @ws.not_nil!.send(payload)
    end

    # TODO: docs
    def request_guild_members(guild_id : Snowflake)
      raise "unimplemented"
    end

    # TODO: docs
    def update_voice_state
      raise "unimplemented"
    end

    # TODO: docs
    def update_status
      raise "unimplemented"
    end

    # Receives the next gateway message from this shard. This can be
    # a signal that the shard has connected, a packet, or a close frame.
    # Returns `nil` if the shard has been disconnected.
    def receive : Event?
      @channel.receive?
    end
  end
end
