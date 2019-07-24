require "base64"
require "http/web_socket"
require "http/client"
require "json"
require "logger"
require "zlib"

module Cryogonal
  VERSION = "0.1.0"

  # The default logger used in components across the library. Can be mutated
  # in order to be customized, or alternatively, you can pass your own logger
  # instances to individual components.
  LOGGER = Logger.new(STDOUT).tap do |logger|
    logger.progname = "cryogonal"
  end

  # Components for connecting and receiving real time events from Discord's
  # gateway service. If you are building any kind of application that reacts
  # to events (messages, changes) that occur on Discord, you should use the
  # gateway API to listen to them.
  module Gateway
  end

  # Components for interacting with Discord's REST HTTP API. To perform actions
  # on Discord, you should use this module. This provides facilities for
  # automatic rate limit handling, so you don't need to handle this yourself.
  # Note that in some cases, encountering rate limits is entirely expected, and
  # cannot be avoided. If you make frequent calls to the HTTP API, you should
  # consider using a cache when eventually consistent data is acceptable.
  module REST
  end
end

require "./snowflake"
require "./token"

require "./gateway/event"
require "./gateway/compressors"
require "./gateway/decoders"
require "./gateway/commands"
require "./gateway/shard"

require "./rest/limit"
