require "../spec_helper"

describe Cryogonal::Gateway::Close do
  it "parses string encoded close frame" do
    raw_frame = Bytes.new(5)

    IO::ByteFormat::NetworkEndian.encode(1_u16, raw_frame[0, 2])
    close_with_code = String.new(raw_frame[0, 2])

    "foo".to_slice.copy_to(raw_frame[2..])
    close_with_reason = String.new(raw_frame)

    close = Cryogonal::Gateway::Close.new(close_with_code)
    close.code.should eq 1
    close.reason.should eq nil

    close = Cryogonal::Gateway::Close.new(close_with_reason)
    close.code.should eq 1
    close.reason.should eq "foo"
  end
end

describe Cryogonal::Gateway::Packet do
  example_json = %({"op":0,"s":1,"d":{"foo":"bar"},"t":"event type"})

  it "deserializes" do
    packet = Cryogonal::Gateway::Packet.from_json(example_json)
    packet.opcode.should eq Cryogonal::Gateway::Opcode::Dispatch
    packet.sequence.should eq 1
    packet.data.to_s.should eq %({"foo":"bar"})
    packet.event_type.should eq "event type"
  end

  it "serializes" do
    packet = Cryogonal::Gateway::Packet.new(:dispatch, 1, IO::Memory.new(%({"foo":"bar"})), "event type")
    packet.to_json.should eq example_json
  end
end
