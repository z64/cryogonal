module Cryogonal::Gateway
  # Exception raised when an unknown decoder is selected.
  class UnknownDecoder < Exception
  end

  # :nodoc:
  module Decoder
    abstract def decode(io : IO) : Packet

    def decode(str : String) : Packet
      io = IO::Memory.new(str)
      self.decode(io)
    end

    def decode(bytes : Bytes) : Packet
      io = IO::Memory.new(bytes)
      self.decode(io)
    end

    def self.get(name : String) : Decoder
      case name
      when "json"
        JSONDecoder.new
      else
        raise UnknownDecoder.new(name)
      end
    end
  end

  # :nodoc:
  class JSONDecoder
    include Decoder

    def decode(io : IO) : Packet
      parser = ::JSON::PullParser.new(io)
      Packet.new(parser)
    end
  end
end
