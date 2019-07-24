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
  #   when Cryogonal::Gateway::Disconnected
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

    # Sends the given packet to the gateway.
    #
    # Raises if this shard is not connected yet. (See `Shard#connect`)
    def send(packet : Packet)
      json = packet.to_json
      @logger.debug { "#{@name} Sending: #{json}" }
      @ws.not_nil!.send(json)
    end

    # Sends the given payload to the gateway by calling `to_packet` on the
    # passed-in payload, which should return a `Packet`. This is a convenience
    # method for the case where a new opcode is added, it can be used in a
    # forwards-compatible way for a future library update.
    def send(payload)
      packet = payload.to_packet
      send(packet)
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
    def send(payload : Identify)
      packet = Packet.new(:identify, nil, payload, nil)
      send(packet)
    end

    # Resumes a previous session, typically used after the shard was
    # disconnected for any reason. If the resume is successful, then
    # events that occured while the shard was disconnected will be replayed.
    def send(payload : Resume)
      packet = Packet.new(:resume, nil, payload, nil)
      send(packet)
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
    #   heartbeat = Cryogonal::Gateway::Heartbeat.new(session.sequence)
    #   shard.send(payload)
    #   sleep(heartbeat_interval)
    # end
    # ```
    def send(payload : Heartbeat)
      packet = Packet.new(:heartbeat, nil, payload.sequence, nil)
      send(packet)
    end

    # Requests a guild's members. If successful, they will be received in
    # batches of 1000 memberes in `GUILD_MEMBER_CHUNK` events.
    def send(payload : RequestGuildMembers)
      packet = Packet.new(:heartbeat, nil, payload, nil)
      send(packet)
    end

    # Updates this shards voice state, used for initiating or finalizing
    # a voice session.
    def send(payload : UpdateVoiceState)
      packet = Packet.new(:voice_state_update, nil, payload, nil)
      send(packet)
    end

    # Updates this shards status. This includes showing the shard's current
    # "game", as well as its "online/away/dnd/offline" indicator.
    def send(payload : UpdateStatus)
      packet = Packet.new(:status_update, nil, payload, nil)
      send(packet)
    end

    # Receives the next gateway message from this shard. This can be
    # a signal that the shard has connected, a packet, a close frame,
    # or a signal that the websocket connection closed.
    def receive : Event?
      @channel.receive?
    end
  end
end
