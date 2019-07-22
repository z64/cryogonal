require "./spec_helper"

describe Cryogonal::Token do
  it "infers type from token string" do
    string = ""
    token = Cryogonal::Token.new(string)
    token.type.should eq Cryogonal::Token::Type::Empty

    string = "abc"
    token = Cryogonal::Token.new(string)
    token.type.should eq Cryogonal::Token::Type::Unknown

    string = "Bot foo"
    token = Cryogonal::Token.new(string)
    token.type.should eq Cryogonal::Token::Type::Bot

    string = "Basic foo"
    token = Cryogonal::Token.new(string)
    token.type.should eq Cryogonal::Token::Type::Basic

    string = "Bearer foo"
    token = Cryogonal::Token.new(string)
    token.type.should eq Cryogonal::Token::Type::Bearer
  end

  it "#to_s exposes full token string" do
    token = Cryogonal::Token.new("Bot foo")
    token.to_s.should eq "Bot foo"
  end

  it "#inspect censors token value" do
    token = Cryogonal::Token.new("Bot MzI2NzIxNjMxODYwOTQ4OTky.XTXqrw.A0dA46HlGf4Fiv6XgDr3MGHf8gs")
    token.inspect.should eq "Cryogonal::Token(@type=Bot client_id=326721631860948992)"

    token = Cryogonal::Token.new("Bearer foo")
    token.inspect.should eq "Cryogonal::Token(@type=Bearer)"
  end

  it "asserts token types" do
    token = Cryogonal::Token.new("Bot foo")
    token.bot_type!.should eq nil

    token = Cryogonal::Token.new("Bearer foo")
    token.bearer_type!.should eq nil

    empty_token = Cryogonal::Token.new("")
    expect_raises(Cryogonal::Token::BadTokenType, "Bot token required (given: Empty)") do
      empty_token.bot_type!
    end

    expect_raises(Cryogonal::Token::BadTokenType, "Bearer token required (given: Empty)") do
      empty_token.bearer_type!
    end
  end
end
