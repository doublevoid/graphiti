module Graphiti
  class Scoping::FilterGroupValidator
    VALID_REQUIRED_VALUES = %i[all any]

    def self.raise_unless_filter_group_requirement_valid!(resource, requirement)
      unless VALID_REQUIRED_VALUES.include?(requirement)
        raise Errors::FilterGroupInvalidRequirement.new(
          resource,
          VALID_REQUIRED_VALUES
        )
      end

      true
    end

    def initialize(resource, query_hash)
      @resource = resource
      @query_hash = query_hash
    end

    def raise_unless_filter_group_requirements_met!
      return if grouped_filters.empty?

      case filter_group_requirement
      when :all
        raise_unless_all_requirements_met!
      when :any
        raise_unless_any_requirements_met!
      end

      true
    end

    private

    attr_reader :resource, :query_hash

    def raise_unless_all_requirements_met!
      met = filter_group_names.all? { |filter_name| filter_group_filter_param.key?(filter_name) }

      unless met
        raise Errors::FilterGroupMissingRequiredFilters.new(
          resource,
          filter_group_names,
          filter_group_requirement
        )
      end
    end

    def raise_unless_any_requirements_met!
      met = filter_group_names.any? { |filter_name| filter_group_filter_param.key?(filter_name) }

      unless met
        raise Errors::FilterGroupMissingRequiredFilters.new(
          resource,
          filter_group_names,
          filter_group_requirement
        )
      end
    end

    def filter_group_names
      grouped_filters.fetch(:names, [])
    end

    def filter_group_requirement
      grouped_filters.fetch(:required, :invalid)
    end

    def grouped_filters
      resource.grouped_filters
    end

    def filter_group_filter_param
      base = query_hash.fetch(:filter, {}).dup
      if (tree = query_hash[:filter_logic])
        extract_filter_logic_names(tree).each do |name|
          base[name] ||= nil
        end
      end
      base
    end

    def extract_filter_logic_names(node, names = Set.new)
      kind = (node["kind"] || node[:kind]).to_s
      children = node["of"] || node[:of]

      if %w[any all].include?(kind)
        children.each { |child| extract_filter_logic_names(child, names) }
      else
        names << children[0].to_sym
      end
      names
    end
  end
end
