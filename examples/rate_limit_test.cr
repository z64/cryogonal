require "../src/cryogonal"

alias Cryo = Cryogonal
Cryo::LOGGER.level = :debug

http = Cryo::REST::Client.new(Cryo::Token.new(ENV["TOKEN"]))

def build_request(channel_id : UInt64, content : String)
  request = HTTP::Request.new(
    "POST",
    "/api/v7/channels/#{channel_id}/messages",
    HTTP::Headers{"Content-Type" => "application/json"},
    {content: content}.to_json
  )
  key = Cryo::REST::LimitKey.new(
    :channels_cid_messages,
    :channel_id,
    Cryo::Snowflake.new(channel_id)
  )
  {request, key}
end

7.times do |i|
  if i == 4
    spawn do
      request, key = build_request(602932100508942337, "test #{i}")
      http.send(request, key)
    end
  end
  request, key = build_request(602932100508942337, "test #{i}")
  http.send(request, key)
end

pp(http.@limit_table)
