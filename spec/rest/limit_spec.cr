require "../spec_helper"

describe Cryogonal::REST::ExceededLimit do
  it "deserializes" do
    json = <<-JSON
    {
      "message": "You are being rate limited.",
      "retry_after": 6457,
      "global": false
    }
    JSON

    exceeded = Cryogonal::REST::ExceededLimit.from_json(json)
    exceeded.message.should eq "You are being rate limited."
    exceeded.retry_after.should eq 6457.milliseconds
    exceeded.global.should eq false
  end
end

describe Cryogonal::REST::LimitTable do
  it "groups access to buckets" do
    table = Cryogonal::REST::LimitTable.new

    # Build some keys:
    key_a_1 = Cryogonal::REST::LimitKey.new(:get_resource_a, :channel_id, Cryogonal::Snowflake.new(1))
    key_a_2 = Cryogonal::REST::LimitKey.new(:get_resource_a, :guild_id, Cryogonal::Snowflake.new(2))
    key_b_3 = Cryogonal::REST::LimitKey.new(:get_resource_b, :none, Cryogonal::Snowflake.new(3))

    # Just use the same reset time for all of them for now:
    reset_time = Time.now.at_end_of_day

    # Populate the table:
    table.update(key_a_1, "shared_bucket_1", 5, 4, reset_time)
    table.update(key_a_2, "shared_bucket_1", 5, 3, reset_time)
    table.update(key_b_3, "shared_bucket_2", 1, 1, reset_time)

    # key_a_1 and key_a_2 have different major parameter values, but point to
    # the same bucket. key_b_3 points to its own unique bucket.
    table[key_a_1].should eq table["shared_bucket_1"]
    table[key_a_2].should eq table["shared_bucket_1"]
    table[key_b_3].should eq table["shared_bucket_2"]

    # Buckets fetched from key_a_1 and key_a_2 will be synced: (both have 3/5)
    bucket = table[key_a_1].not_nil!
    bucket.limit.should eq 5
    bucket.remaining.should eq 3
    bucket.reset_time.should eq reset_time

    bucket = table[key_a_2].not_nil!
    bucket.limit.should eq 5
    bucket.remaining.should eq 3
    bucket.reset_time.should eq reset_time

    # Bucket fetched from key_b_3 has its own 1/1 limit:
    bucket = table[key_b_3].not_nil!
    bucket.limit.should eq 1
    bucket.remaining.should eq 1
    bucket.reset_time.should eq reset_time

    # An new key has no value set:
    new_key = Cryogonal::REST::LimitKey.new(:get_resource_z, :none, Cryogonal::Snowflake.new(4))
    table[new_key].should eq nil
    table["unknown"].should eq nil
  end
end

describe Cryogonal::REST::Bucket do
  it "locks when no requests are remaining" do
    bucket = Cryogonal::REST::Bucket.new(5, 0, Time.now + 1.second)
    bucket.next_will_limit(at: Time.now).should eq true
    bucket.next_will_limit(at: 2.seconds.from_now).should eq false
    bucket.on_cooldown.should eq false

    spawn(bucket.cooldown)
    wait_time = Channel(Time::Span?).new
    spawn do
      bucket.on_cooldown.should eq true
      wait_time.send(bucket.wait)
    end
    waited = wait_time.receive.try(&.to_f) || 0.0
    waited.should be_close(1.5, 0.01)
    bucket.wait.should eq nil
  end
end
