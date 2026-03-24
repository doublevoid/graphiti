require "spec_helper"

RSpec.describe Graphiti::Errors::InvalidFilterLogicStructure do
  it "has a descriptive message" do
    error = described_class.new("missing 'kind' key")
    expect(error.message).to include("filter_logic")
    expect(error.message).to include("missing 'kind' key")
  end
end

RSpec.describe Graphiti::Errors::FilterLogicDepthExceeded do
  it "has a descriptive message" do
    error = described_class.new(4)
    expect(error.message).to include("4")
    expect(error.message).to include("depth")
  end
end

RSpec.describe Graphiti::Errors::FilterLogicPrimaryResourceConflict do
  it "has a descriptive message" do
    error = described_class.new([:name, :age])
    expect(error.message).to include("name")
    expect(error.message).to include("age")
    expect(error.message).to include("filter_logic")
  end
end

RSpec.describe Graphiti::Errors::FilterLogicInvalidLeaf do
  it "has a descriptive message" do
    error = described_class.new("attribute 'foo' is not filterable")
    expect(error.message).to include("foo")
    expect(error.message).to include("filterable")
  end
end