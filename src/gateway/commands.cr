module Cryogonal::Gateway
  struct Identify
    include JSON::Serializable

    # :nodoc:
    PROPERTIES = IdentifyProperties.new("Linux", "cryogonal", "cryogonal")

    @token : Token
    @properties : IdentifyProperties
    @large_threshold : Int32?
    @compress : Bool?
    @status : UpdateStatus?
    @shard : Tuple(Int32, Int32)?
    @guild_subscriptions : Bool?

    def initialize(@token, @compress = nil, @large_threshold = nil,
                   @status = nil, @shard = nil, @guild_subscriptions = nil)
      @properties = PROPERTIES
    end
  end

  # :nodoc:
  struct IdentifyProperties
    include JSON::Serializable

    @[JSON::Field(key: "$os")]
    @os : String

    @[JSON::Field(key: "$browser")]
    @browser : String

    @[JSON::Field(key: "$device")]
    @device : String

    def initialize(@os, @browser, @device)
    end
  end

  struct UpdateStatus
    include JSON::Serializable

    @[JSON::Field(converter: Cryogonal::Gateway::PresenceTimeConverter)]
    @since : Time?

    @[JSON::Field(key: "game")]
    @activity : Activity?

    @status : Status
    @afk : Bool

    def initialize(@since, @activity, @status, @afk)
    end
  end

  # :nodoc:
  module PresenceTimeConverter
    def self.to_json(value : Time, builder : JSON::Builder)
      unix = value.to_unix
      unix.to_json(builder)
    end
  end

  enum Status : UInt8
    Online
    Offline
    Dnd
    Invisible

    def to_json(builder : JSON::Builder)
      case self
      when Online    then builder.string("online")
      when Offline   then builder.string("offline")
      when Dnd       then builder.string("dnd")
      when Invisible then builder.string("invisible")
      end
    end
  end

  struct Activity
    include JSON::Serializable

    @name : String
    @type : ActivityType
    @url : String?
  end

  enum ActivityType : UInt8
    Game
    Streaming
    Listening
  end

  struct Resume
    include JSON::Serializable

    @token : Token
    @session_id : String
    @sequence : Int64

    def initialize(@token, @session_id, @sequence)
    end
  end

  struct Heartbeat
    include JSON::Serializable

    getter sequence : Int64?

    def initialize(@sequence)
    end
  end

  struct RequestGuildMembers
    include JSON::Serializable

    @guild_id : Snowflake | Array(Snowflake)
    @query : String
    @limit : Int32

    def initialize(@guild_id, @query, @limit)
    end
  end

  struct UpdateVoiceState
    include JSON::Serializable

    @guild_id : Snowflake
    @channel_id : Snowflake
    @self_mute : Bool
    @self_deaf : Bool

    def initialize(@guild_id, @channel_id, @self_mute, @self_deaf)
    end
  end
end
