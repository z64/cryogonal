require "../src/cryogonal"

struct Hello
  include JSON::Serializable

  module MsConverter
    def self.from_json(parser)
      parser.read_int.milliseconds
    end
  end

  @[JSON::Field(converter: Hello::MsConverter)]
  getter heartbeat_interval : Time::Span
end

struct Message
  include JSON::Serializable
  getter content : String
end

struct State
  property hb_interval : Time::Span? = nil
  property sequence : Int64? = nil
end

token = Cryogonal::Token.new(ENV["TOKEN"])
shard = Cryogonal::Gateway::Shard.new
state = State.new

spawn(shard.connect("wss://gateway.discord.gg?v=6&compress=zlib-stream"))
while message = shard.receive
  case message
  when Cryogonal::Gateway::Connected
    identify = Cryogonal::Gateway::Identify.new(token)
    shard.send(identify)
  when Cryogonal::Gateway::Packet
    case message.opcode
    when .hello?
      hello = Hello.from_json(message.data)
      hb_interval = hello.heartbeat_interval

      state.hb_interval = hb_interval
      period_offset = rand(hb_interval.total_seconds)
      spawn do
        sleep(period_offset)
        while interval = state.hb_interval
          heartbeat = Cryogonal::Gateway::Heartbeat.new(state.sequence)
          shard.send(heartbeat)
          sleep(interval)
        end
      end
    when .dispatch?
      state.sequence = message.sequence
      Cryogonal::LOGGER.info("#{shard.name} #{message.event_type}")
      case message.event_type
      when "MESSAGE_CREATE"
        payload = Message.from_json(message.data)
        Cryogonal::LOGGER.info("#{shard.name} #{payload}")
        if payload.content == "!quit"
          shard.disconnect
        end
      end
    end
  when Cryogonal::Gateway::Close, Cryogonal::Gateway::Disconnected
    state.hb_interval = nil
    break
  end
end
