require "zlib"

module Cryogonal::Gateway
  # Exception raised when an unknown compressor is selected.
  class UnknownCompressor < Exception
  end

  # :nodoc:
  module Compressor
    abstract def read(bytes : Bytes) : Bytes?

    # Fetches a `Compressor` implementation by its canonical name, generally
    # as expected in a gateway URI connection string.
    def self.get(name : String) : Compressor
      case name
      when "zlib"
        ZlibCompressor.new
      when "zlib-stream"
        ZlibStreamCompressor.new
      else
        raise UnknownCompressor.new(name)
      end
    end
  end

  # :nodoc:
  # Utility class for inflating large compressed payloads from the gateway.
  #
  # NOTE: Instances of this class should *not* be shared between multiple connections.
  class ZlibCompressor
    include Compressor

    def initialize
      @zlib_io = IO::Memory.new
    end

    def read(bytes : Bytes) : Bytes?
      @zlib_io.write(bytes)
      @zlib_io.rewind

      reader = Zlib::Reader.new(@zlib_io)
      buffer = IO::Memory.new
      IO.copy(reader, buffer)
      @zlib_io.clear

      buffer.to_slice
    end
  end

  # :nodoc:
  # Utility class for inflating `zlib-stream` binary frames from the gateway.
  #
  # NOTE: Instances of this class should *not* be shared between multiple connections.
  class ZlibStreamCompressor
    include Compressor

    # :nodoc:
    ZLIB_SUFFIX = Bytes[0x0, 0x0, 0xFF, 0xFF]

    @buffer : Bytes
    @zlib_reader : Zlib::Reader?

    def initialize(buffer_size = 10 * 1024 * 1024)
      @buffer_memory = Bytes.new(buffer_size)
      @buffer = @buffer_memory[0, 0]
      @zlib_io = IO::Memory.new
      @zlib_reader = nil
    end

    # Attempts to read a message given the additional bytes. Returns the
    # inflated bytes if they resulted in a complete message.
    def read(bytes : Bytes) : Bytes?
      @zlib_io.write(bytes)
      return if bytes.size < 4 || bytes[bytes.size - 4, 4] != ZLIB_SUFFIX
      @zlib_io.rewind

      reader = (@zlib_reader ||= Zlib::Reader.new(@zlib_io))
      read_size = reader.read(@buffer_memory)
      @zlib_io.clear
      @buffer_memory[0, read_size]
    end
  end
end
