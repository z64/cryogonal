require "./spec_helper"

describe Cryogonal::Snowflake do
  describe Cryogonal::Snowflake::SNOWFLAKE_EPOCH do
    it "is 2015-01-01" do
      expected = Time.utc(2015, 1, 1)
      Cryogonal::Snowflake::SNOWFLAKE_EPOCH.should eq expected.to_unix_ms
    end
  end

  it "#to_json" do
    snowflake = Cryogonal::Snowflake.new(0_u64)
    json = JSON.build do |builder|
      snowflake.to_json(builder)
    end
    json.should eq %("0")
  end

  it ".from_json" do
    parser = JSON::PullParser.new(%("0"))
    snowflake = Cryogonal::Snowflake.new(parser)
    snowflake.to_u64.should eq 0_u64
  end

  describe Array(Cryogonal::Snowflake) do
    it "can be sorted" do
      snowflake_a = Cryogonal::Snowflake.new(2_u64)
      snowflake_b = Cryogonal::Snowflake.new(1_u64)
      snowflake_c = Cryogonal::Snowflake.new(0_u64)

      array = [snowflake_a, snowflake_b, snowflake_c]
      array.sort.should eq [snowflake_c, snowflake_b, snowflake_a]
    end
  end

  describe "#creation_time" do
    it "returns the time the snowflake was created" do
      time = Time.utc(2018, 4, 18)
      snowflake = Cryogonal::Snowflake.new(time)
      snowflake.creation_time.should eq time
    end
  end

  it "compares to uint64" do
    snowflake = Cryogonal::Snowflake.new(1_u64)
    (snowflake == 1_u64).should be_true
    (snowflake == 0_u64).should be_false
  end
end

describe UInt64 do
  it "compares to snowflake" do
    snowflake = Cryogonal::Snowflake.new(1_u64)
    (1_u64 == snowflake).should be_true
    (0_u64 == snowflake).should be_false
  end
end
