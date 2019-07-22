module Cryogonal::Gateway
  # Possible types that can be received from the gateway
  alias Event = Connected | Packet | Close | Disconnected

  # Unit struct representing that a connection was established.
  struct Connected
  end

  # Unit struct representing that a connection was lost.
  struct Disconnected
  end

  # Data returned from the gateway when the connection is closed.
  struct Close
    getter code : UInt16
    getter reason : String?

    # :nodoc:
    # TODO: Refactor once std `WebSocket` supports close frame decoding
    def self.new(string : String)
      bytes = string.to_slice
      code = IO::ByteFormat::NetworkEndian.decode(UInt16, bytes[0, 2])
      message = nil
      if bytes.size > 2
        message = String.new(bytes[2..])
      end
      Close.new(code, message)
    end

    # :nodoc:
    def initialize(@code : UInt16, @reason : String?)
    end
  end

  # A single message received from the gateway.
  struct Packet
    include ::JSON::Serializable

    @[JSON::Field(key: "op")]
    getter opcode : Opcode

    @[JSON::Field(key: "s")]
    getter sequence : Int64?

    @[JSON::Field(key: "d", converter: Cryogonal::Gateway::RawPayloadConverter)]
    getter data : IO::Memory

    @[JSON::Field(key: "t")]
    getter event_type : String?

    def initialize(@opcode : Opcode, @sequence : Int64?, @data : IO::Memory,
                   @event_type : String?)
    end

    def inspect(io : IO)
      io << "Cryogonal::WebSocket::Packet(@opcode="
      opcode.inspect(io)
      io << " @sequence="
      sequence.inspect(io)
      io << " @data="
      data.to_s.inspect(io)
      io << " @event_type="
      event_type.inspect(io)
      io << ')'
    end
  end

  # Value that describes the kind of packet received from the gateway.
  enum Opcode : UInt8
    Dispatch            =  0
    Heartbeat           =  1
    Identify            =  2
    StatusUpdate        =  3
    VoiceStateUpdate    =  4
    VoiceServerPing     =  5
    Resume              =  6
    Reconnect           =  7
    RequestGuildMembers =  8
    InvalidSession      =  9
    Hello               = 10
    HeartbeatAck        = 11

    def self.new(parser : JSON::PullParser)
      Opcode.new(parser.read_int.to_u8)
    end
  end

  # :nodoc:
  module RawPayloadConverter
    def self.from_json(parser : JSON::PullParser) : IO::Memory
      buffer = IO::Memory.new
      JSON.build(buffer) do |builder|
        parser.read_raw(builder)
      end
      buffer.rewind
    end

    def self.to_json(buffer : IO::Memory, builder : JSON::Builder)
      builder.raw(buffer.to_s)
    end
  end
end
