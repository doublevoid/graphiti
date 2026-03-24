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

RSpec.describe "filter_logic_max_depth configuration" do
  let(:parent_resource) do
    Class.new(PORO::EmployeeResource) do
      def self.name
        "PORO::EmployeeResource"
      end
      self.filter_logic_max_depth = 5
    end
  end

  let(:child_resource) do
    parent = parent_resource
    Class.new(parent) do
      def self.name
        "PORO::EmployeeResource"
      end
    end
  end

  it "defaults to 4" do
    expect(PORO::EmployeeResource.filter_logic_max_depth).to eq(4)
  end

  it "is configurable on a resource" do
    expect(parent_resource.filter_logic_max_depth).to eq(5)
  end

  it "is inherited by child resources" do
    expect(child_resource.filter_logic_max_depth).to eq(5)
  end

  it "can be overridden on child resources" do
    child_resource.filter_logic_max_depth = 3
    expect(child_resource.filter_logic_max_depth).to eq(3)
    expect(parent_resource.filter_logic_max_depth).to eq(5)
  end
end