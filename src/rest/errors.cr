module Cryogonal::REST
  class APIException < Exception
    getter response : HTTP::Client::Response
    getter error : APIError?

    def initialize(@response : HTTP::Client::Response)
      @error = nil
      if @response.headers["Content-Type"] == "application/json"
        begin
          @error = APIError.from_json(response.body)
        rescue JSON::ParseException
        end
      end
    end

    def to_s(io)
      status = @response.status
      io << status.code << ' ' << status.description
      if error = @error
        io.print('\n')
        error.to_s(io)
      end
    end

    def message
      self.to_s
    end
  end

  record(APIError, code : Int64, errors : ErrorNode?, message : String) do
    include JSON::Serializable

    def to_s(io)
      io << message << " (Error code " << code << ')'
      if node = @errors
        io.print(":\n")
        node.to_s(io, 2)
      end
    end
  end

  record(ErrorDescription, code : String, message : String) do
    include JSON::Serializable

    def to_s(io)
      io << message << " (" << code << ')'
    end
  end

  struct ErrorNode
    getter value : Hash(String, ErrorNode) | Array(ErrorDescription)?
    protected setter value

    def self.new(parser : JSON::PullParser)
      node = ErrorNode.new
      case kind = parser.kind
      when :begin_object
        parser.read_begin_object
        case key = parser.read_string
        when "_errors"
          node.value = Array(ErrorDescription).new(parser)
          parser.read_end_object
        else
          hash = Hash(String, ErrorNode).new
          hash[key] = ErrorNode.new(parser)
          until parser.kind == :end_object
            key = parser.read_string
            hash[key] = ErrorNode.new(parser)
          end
          parser.read_end_object
          node.value = hash
        end
      else
        raise JSON::ParseException.new("Unhandled node kind: #{kind}",
          parser.line_number, parser.column_number)
      end
      node
    end

    def initialize(@value = nil)
    end

    def to_s(io, indent = 0, root = nil)
      case value = @value
      when Hash(String, ErrorNode)
        value.each do |key, next_node|
          indent.times { io.print(' ') }
          if next_node.value.is_a?(Array(ErrorDescription))
            next_node.to_s(io, indent, key)
          else
            io << "In " << key.inspect << ":\n"
            next_node.to_s(io, indent + 2, nil)
          end
        end
      when Array(ErrorDescription)
        value.each do |error|
          io << root.inspect << " "
          error.to_s(io)
          io.print('\n')
        end
      end
    end
  end
end
