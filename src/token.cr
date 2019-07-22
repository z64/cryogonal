# Struct used for storing an authorization token for performing actions with
# Discord's API.
#
# See the [API Reference](https://discordapp.com/developers/docs/reference#authentication)
# for details on authentication.
struct Cryogonal::Token
  # Returns a new `Token` struct, with the `type` inferred from the beginning
  # of the token string.
  #
  # ```
  # Cryogonal::Token.new("Bot ...")    # => Cryogonal::Token(@type=Bot)
  # Cryogonal::Token.new("Bearer ...") # => Cryogonal::Token(@type=Bearer)
  # Cryogonal::Token.new("...")        # => Cryogonal::Token(@type=Unknown)
  # ```
  def self.new(string : String) : Token
    type = Type::Unknown

    case string
    when .empty?                  then type = Type::Empty
    when .starts_with?("Bot ")    then type = Type::Bot
    when .starts_with?("Basic ")  then type = Type::Basic
    when .starts_with?("Bearer ") then type = Type::Bearer
    end

    Token.new(type, string)
  end

  enum Type : UInt8
    Empty   = 0
    Unknown = 1
    Bot     = 2
    Basic   = 3
    Bearer  = 4
  end

  # Exception raised when a token of an unexpected type was used
  # in a way that is guarenteed to fail.
  class BadTokenType < Exception
  end

  # The type of this token, used by the library to infer whether certain
  # actions are possible given the context in which the token is applied.
  #
  # For example, a `Bearer` token cannot be used to establish a gateway
  # connection.
  getter type : Type

  # :nodoc:
  def initialize(@type : Type, @string : String)
  end

  # Returns the full token string.
  #
  # NOTE: Do not share this value with any untrusted code! If you do,
  #   make sure you go into the developer panel for your application
  #   and reset it immediately.
  def to_s(io : IO)
    @string.to_s(io)
  end

  # Asserts this token is a `Bot` type, raising a `BadTokenType` exception if
  # it isn't. Does nothing if we aren't sure what kind of token it is.
  def bot_type!
    unless @type.unknown?
      raise(BadTokenType.new("Bot token required (given: #{@type})")) if @type != Type::Bot
    end
  end

  # Asserts this token is a `Bearer` type, raising a `BadTokenType` exception if
  # it isn't. Does nothing if we aren't sure what kind of token it is.
  def bearer_type!
    unless @type.unknown?
      raise(BadTokenType.new("Bearer token required (given: #{@type})")) if @type != Type::Bearer
    end
  end

  # Inspects this token. This **does not** expose the raw token value. Only
  # the token's type in this representation is exposed.
  #
  # If this is interpreted as a bot token, it will attempt to display the
  # client ID this token belongs to. The client ID is **not** private and can
  # be safely shared with anyone.
  def inspect
    String.build do |str|
      self.inspect(str)
    end
  end

  # :ditto:
  def inspect(io : IO)
    io.print("Cryogonal::Token(@type=#{self.type}")

    if self.type.bot? && (client_id = parse_client_id)
      io.print(" client_id=#{client_id}")
    end

    io.print(')')
  end

  private def parse_client_id
    token_value = @string.lchop("Bot ")
    dot_index = token_value.index('.')
    Base64.decode_string(token_value[...dot_index])
  rescue
    nil
  end
end
