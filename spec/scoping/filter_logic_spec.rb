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

RSpec.describe Graphiti::Scoping::FilterLogic do
  include_context "resource testing"

  let(:resource) do
    Class.new(PORO::EmployeeResource) do
      def self.name
        "PORO::EmployeeResource"
      end
    end
  end
  let(:base_scope) { {type: :employees, conditions: {}} }

  describe "tree validation" do
    context "with valid simple leaf" do
      before do
        params[:filter_logic] = {kind: "eq", of: ["first_name", "Stephen"]}.to_json
      end

      it "does not raise" do
        expect { records }.not_to raise_error
      end
    end

    context "with valid group node" do
      before do
        params[:filter_logic] = {
          kind: "any",
          of: [
            {kind: "eq", of: ["first_name", "Stephen"]},
            {kind: "eq", of: ["first_name", "Agatha"]}
          ]
        }.to_json
      end

      it "does not raise" do
        expect { records }.not_to raise_error
      end
    end

    context "with single-element group" do
      before do
        params[:filter_logic] = {
          kind: "any",
          of: [{kind: "eq", of: ["first_name", "Stephen"]}]
        }.to_json
      end

      it "does not raise" do
        expect { records }.not_to raise_error
      end
    end

    context "with missing 'kind' key" do
      before do
        params[:filter_logic] = {of: ["first_name", "Stephen"]}.to_json
      end

      it "raises InvalidFilterLogicStructure" do
        expect { records }.to raise_error(
          Graphiti::Errors::InvalidFilterLogicStructure,
          /kind/
        )
      end
    end

    context "with missing 'of' key" do
      before do
        params[:filter_logic] = {kind: "eq"}.to_json
      end

      it "raises InvalidFilterLogicStructure" do
        expect { records }.to raise_error(
          Graphiti::Errors::InvalidFilterLogicStructure,
          /of/
        )
      end
    end

    context "with group node having empty 'of'" do
      before do
        params[:filter_logic] = {kind: "any", of: []}.to_json
      end

      it "raises InvalidFilterLogicStructure" do
        expect { records }.to raise_error(
          Graphiti::Errors::InvalidFilterLogicStructure
        )
      end
    end

    context "with leaf node having wrong number of elements in 'of'" do
      before do
        params[:filter_logic] = {kind: "eq", of: ["first_name"]}.to_json
      end

      it "raises InvalidFilterLogicStructure" do
        expect { records }.to raise_error(
          Graphiti::Errors::InvalidFilterLogicStructure
        )
      end
    end

    context "with depth exceeding max" do
      before do
        resource.filter_logic_max_depth = 2
        # Depth 3: any -> all -> any (exceeds max of 2)
        params[:filter_logic] = {
          kind: "any",
          of: [
            {kind: "all",
             of: [
               {kind: "any",
                of: [
                  {kind: "eq", of: ["first_name", "Stephen"]},
                  {kind: "eq", of: ["first_name", "Agatha"]}
                ]},
               {kind: "eq", of: ["first_name", "William"]}
             ]},
            {kind: "eq", of: ["first_name", "Harold"]}
          ]
        }.to_json
      end

      it "raises FilterLogicDepthExceeded" do
        expect { records }.to raise_error(
          Graphiti::Errors::FilterLogicDepthExceeded
        )
      end
    end

    context "with non-filterable attribute" do
      before do
        params[:filter_logic] = {kind: "eq", of: ["nonexistent", "value"]}.to_json
      end

      it "raises AttributeError" do
        expect { records }.to raise_error(Graphiti::Errors::AttributeError)
      end
    end

    context "with disallowed operator" do
      before do
        resource.filter :first_name, :string, only: [:eq]
        params[:filter_logic] = {kind: "prefix", of: ["first_name", "Ste"]}.to_json
      end

      it "raises UnsupportedOperator" do
        expect { records }.to raise_error(Graphiti::Errors::UnsupportedOperator)
      end
    end
  end
end
