# Routes and major parameters:
#
#   Ex: GET /users/{id}
#   1. Bucket is always aa6a962e04660e4eb788914e1ef32c12 regardless of ID value
#   2. Remaining decreases regardless of ID value
#
#   Ex: POST /channels/{id}/messages
#   1. Bucket is always 80c17d2f203122d936070c88c8d10f33 regardless of ID value
#   2. Remaining decreases per-ID value
#
#   Ex: GET /guilds/{gid}/members/{uid}
#   1. Bucket is always 63e8b9f22df9dc9ef04cd65af6244664 regardless of either ID value
#   2. Remaining decreases regardless of user ID value
#   3. Different guild ID accesses a different bucket
#
# Rate limit identification:
#
#   A route and its major parameter, if any, fully identify a rate limiting bucket
#   on Discord's end. The ID of this bucket is not known until a request is made.
#   Furthermore, multiple routes may share a bucket - i.e., two unique routes will
#   resolve to the same bucket ID after making a request with each individually.
#
#   Key       Value                  Data
#   -------------------------------------------------------------
#   ROUTE_A | - - -                |
#           |      \               |
#   ROUTE_B | - - - - BUCKET_ID -> | {limit, remaining, reset_at}
#           |      /  (not known   |
#   ROUTE_C | - - -    until 1st   |
#           |          request)    |
#   ROUTE_D | - - -                |
#           |      \               |
#   ROUTE_E | - - - - BUCKET_ID -> | {limit, remaining, reset_at}
#           |      /               |
#   ROUTE_F | - - -                |
#
# Rate limiting process:
#
#   1. Prepare to make request to ROUTE. Check for known limit by ROUTE -> BUCKET ID.
#   2. If BUCKET_ID was known, access its rate limit data.
#   3. Lock the associated mutex if remaining is 0 until the limit resets.
#   4. Update the stored limit after the request is done.

module Cryogonal::REST
  # Values that identify a client-side bucket key. This includes the HTTP route,
  # the type of major parameter, and its ID value, if any.
  record(LimitKey, route : Symbol, major_parameter : MajorParameter, id : Snowflake?) do
    def self.global
      LimitKey.new(:global, :none, nil)
    end

    def inspect(io)
      io << '/' << @route << '/' << @major_parameter << '/' << @id || "none"
    end
  end

  # Major parameter types. This is not required for correct rate limiting
  # implementations - it is only used as metadata to be stored with the
  # major parameter snowflake for logging / debugging purposes.
  enum MajorParameter : UInt8
    None
    ChannelID
    GuildID
    WebhookID
  end

  # Representation of an observed limit state, including a lock.
  class Bucket
    # Total number of requests the bucket is limited to, per period.
    property limit : Int32

    # Total number of requests remaining before exceeding the limit.
    property remaining : Int32

    # Time at which the remaining amount of requests will be reset to its full value.
    property reset_time : Time

    # Whether this bucket is currently on cooldown.
    getter on_cooldown : Bool

    def initialize(@limit, @remaining, @reset_time)
      @mutex = Mutex.new
      @on_cooldown = false
    end

    # Checks whether this bucket is empty. If it is, this means the next
    # request on this bucket will exceed the rate limit.
    def next_will_limit(at time : Time = Time.now)
      @remaining - 1 < 0 && time <= @reset_time
    end

    # Waits until this bucket is no longer on cooldown.
    # Returns the amount of time waited, if any.
    def wait : Time::Span?
      return unless @on_cooldown
      Time.measure do
        @mutex.lock
        @mutex.unlock
      end
    end

    # Waits for this bucket to cool down, until `reset_time` has been passed.
    def cooldown(from time : Time = Time.now)
      remaining_time = @reset_time - time
      if remaining_time >= Time::Span.zero
        @on_cooldown = true
        @mutex.synchronize { sleep(remaining_time) }
        @on_cooldown = false
      else
        raise "Cannot wait negative time for bucket (check clock sync? #{remaining_time})"
      end
    end
  end

  # Table that manages a dual index to `Bucket` instances. One by limit key,
  # the other by its identified server-side bucket ID.
  class LimitTable
    def initialize
      @bucket_key_index = Hash(LimitKey, Bucket).new
      @bucket_id_index = Hash(String, Bucket).new
    end

    def [](key : LimitKey) : Bucket?
      @bucket_key_index[key]?
    end

    def [](id : String) : Bucket?
      @bucket_id_index[id]?
    end

    # Tries to update a bucket using the passed HTTP headers. If the headers
    # do not have enough information, no action is taken.
    def update(key : LimitKey, headers : HTTP::Headers)
      limit_value = headers["X-RateLimit-Limit"]?
      remaining_value = headers["X-RateLimit-Remaining"]?
      bucket_id = headers["X-RateLimit-Bucket"]?
      reset_time_value = headers["X-RateLimit-Reset"]?
      retry_after_value = headers["Retry-After"]?
      server_date_value = headers["Date"]?

      # If all "normal" headers present, use those values.
      #
      # If Retry-After was specified, the servers date will be parsed (with a
      # fallback to the current time) and reset_time will be set from this time
      # offset by Retry-After milliseconds.
      #
      # Otherwise, if only Retry-After was present (i.e., a global rate limit
      # was encountered) then we construct a bucket with some "fake" values so
      # it will work and lock properly.
      if limit_value && remaining_value && reset_time_value && bucket_id
        reset_time = if retry_after_value && server_date_value
                       server_time = HTTP.parse_time(server_date_value) || Time.now
                       server_time + retry_after_value.to_i.milliseconds
                     else
                       Time.unix(reset_time_value.to_i)
                     end
        update(key, bucket_id, limit_value.to_i, remaining_value.to_i, reset_time)
      elsif retry_after_value
        server_time = nil
        if server_date_value
          server_time = HTTP.parse_time(server_date_value)
        end
        server_time ||= Time.now
        reset_time = server_time + retry_after_value.to_i.milliseconds
        update(key, bucket_id, 0, 0, reset_time)
      else
        # TODO: error class
        raise "Failed to construct bucket for #{key} from headers: #{headers}"
      end
    end

    # Updates a bucket at the given key and server-side bucket ID with the
    # given rate limit information. This update ensures that future lookups by
    # key or bucket ID point to the same `Bucket` instance, ensuring that
    # different routes with the same server-side bucket ID are kept in sync.
    def update(key : LimitKey, bucket_id : String?, limit : Int32,
               remaining : Int32, reset_time : Time)
      if known_bucket = @bucket_id_index[bucket_id]?
        known_bucket.limit = limit
        known_bucket.remaining = remaining
        known_bucket.reset_time = reset_time
        @bucket_key_index[key] = known_bucket
      else
        identified_bucket = Bucket.new(limit, remaining, reset_time)
        @bucket_key_index[key] = identified_bucket
        if bucket_id
          @bucket_id_index[bucket_id] = identified_bucket
        end
      end
    end
  end

  # Information returned when a rate limit is exceeded, i.e., a 429. This
  # identifies how long to pause requests for, and whether it is a global
  # penalty.
  struct ExceededLimit
    include JSON::Serializable

    getter message : String

    @[JSON::Field(converter: Cryogonal::REST::RetryAfterConverter)]
    getter retry_after : Time::Span

    getter global : Bool
  end

  # :nodoc:
  module RetryAfterConverter
    def self.from_json(parser : JSON::PullParser)
      parser.read_int.milliseconds
    end
  end
end
