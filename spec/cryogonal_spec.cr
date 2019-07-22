require "yaml"
require "./spec_helper"

describe Cryogonal::VERSION do
  it "matches shard.yml" do
    yaml = YAML.parse(File.read("shard.yml"))
    yaml["version"].should eq Cryogonal::VERSION
  end
end
