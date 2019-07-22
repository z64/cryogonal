# Struct wrapping a Discord ID. They are represented as `UInt64` integers that
# contain encoded metadata, such as the time the ID was created. This struct
# provides methods for accessing that data, and comparing this ID with others.
#
# [API docs for this type](https://discordapp.com/developers/docs/reference#snowflakes)
struct Cryogonal::Snowflake
  include Comparable(Snowflake)
  include Comparable(UInt64)

  # :nodoc:
  SNOWFLAKE_EPOCH = 1420070400000_u64

  # Creates a snowflake from a string-encoded value.
  def self.new(string : String)
    new(string.to_u64)
  end

  # Reads a `Snowflake` from a `JSON::PullParser`. This expects that
  # the snowflake value is string encoded.
  def self.new(parser : JSON::PullParser)
    string = parser.read_string
    new(string.to_u64)
  end

  # Creates a `Snowflake` embedded with the given timestamp.
  def self.new(time : Time)
    ms = time.to_unix_ms.to_u64
    value = (ms - SNOWFLAKE_EPOCH) << 22
    new(value)
  end

  def initialize(@value : UInt64)
  end

  def to_u64
    @value
  end

  def to_s(io : IO)
    io << @value
  end

  # The time at which this snowflake was created.
  def creation_time : Time
    ms = (@value >> 22) + SNOWFLAKE_EPOCH
    Time.unix_ms(ms)
  end

  # Encodes this snowflake to a `JSON::Builder`. The snowflakes `UInt64`
  # representation will be string encoded to the builder.
  def to_json(builder : JSON::Builder)
    builder.scalar @value.to_s
  end

  def <=>(other : Snowflake)
    @value <=> other.to_u64
  end

  def <=>(int : UInt64)
    @value <=> int
  end
end

struct UInt64
  include Comparable(Cryogonal::Snowflake)

  def <=>(snowflake : Cryogonal::Snowflake)
    self <=> snowflake.to_u64
  end
end
