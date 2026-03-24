require "spec_helper"

RSpec.describe Graphiti::Query do
  let(:resource) { PORO::EmployeeResource.new }
  let(:params) { {} }
  subject(:query) { described_class.new(resource, params) }

  describe "#filter_logic" do
    context "when filter_logic param is present" do
      let(:tree) { {"kind" => "eq", "of" => ["first_name", "Stephen"]} }
      let(:params) { {filter_logic: tree.to_json} }

      it "parses the JSON and returns the tree" do
        expect(query.filter_logic).to eq(tree)
      end
    end

    context "when filter_logic param is absent" do
      it "returns nil" do
        expect(query.filter_logic).to be_nil
      end
    end

    context "when filter_logic is invalid JSON" do
      let(:params) { {filter_logic: "not json{"} }

      it "raises InvalidFilterLogicStructure" do
        expect { query.filter_logic }.to raise_error(
          Graphiti::Errors::InvalidFilterLogicStructure
        )
      end
    end
  end

  describe "#filters with filter_logic present" do
    let(:tree) { {"kind" => "eq", "of" => ["first_name", "Stephen"]} }

    context "when filter has primary resource keys" do
      let(:params) do
        {
          filter_logic: tree.to_json,
          filter: {first_name: "Stephen"}
        }
      end

      it "raises FilterLogicPrimaryResourceConflict" do
        expect { query.hash }.to raise_error(
          Graphiti::Errors::FilterLogicPrimaryResourceConflict
        )
      end
    end

    context "when filter has only sideload (dotted) keys" do
      let(:params) do
        {
          filter_logic: tree.to_json,
          filter: {"positions.title": "Manager"}
        }
      end

      it "does not raise" do
        expect { query.hash }.not_to raise_error
      end
    end
  end

  describe "#hash with filter_logic" do
    let(:tree) { {"kind" => "eq", "of" => ["first_name", "Stephen"]} }
    let(:params) { {filter_logic: tree.to_json} }

    it "includes filter_logic in the hash" do
      expect(query.hash[:filter_logic]).to eq(tree)
    end
  end
end
