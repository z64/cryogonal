require "../spec_helper"

describe Cryogonal::REST::APIException do
  it "deserializes API error bodies" do
    json = <<-JSON
    {
      "code": 1,
      "message": "error message"
    }
    JSON

    response = HTTP::Client::Response.new(200, json,
      HTTP::Headers{"Content-Type" => "application/json"})

    expected_error = Cryogonal::REST::APIError.new(1, nil, "error message")
    exception = Cryogonal::REST::APIException.new(response)
    exception.response.should eq response
    exception.error.should eq expected_error
  end
end

describe Cryogonal::REST::APIError do
  it "parses and pretty prints errors" do
    json = <<-JSON
    {
      "code": 50035,
      "errors": {
        "content": {
          "_errors": [
            {
              "code": "BASE_TYPE_MAX_LENGTH",
              "message": "Must be 2000 or fewer in length."
            }
          ]
        },
        "embed": {
          "description": {
            "_errors": [
              {
                "code": "BASE_TYPE_MAX_LENGTH",
                "message": "Must be 2048 or fewer in length."
              }
            ]
          },
          "title": {
            "_errors": [
              {
                "code": "BASE_TYPE_MAX_LENGTH",
                "message": "Must be 256 or fewer in length."
              }
            ]
          }
        }
      },
      "message": "Invalid Form Body"
    }
    JSON

    error = Cryogonal::REST::APIError.from_json(json)
    error.to_s.should eq <<-ERR
    Invalid Form Body (Error code 50035):
      "content" Must be 2000 or fewer in length. (BASE_TYPE_MAX_LENGTH)
      In "embed":
        "description" Must be 2048 or fewer in length. (BASE_TYPE_MAX_LENGTH)
        "title" Must be 256 or fewer in length. (BASE_TYPE_MAX_LENGTH)

    ERR
  end
end
