module Graphiti
  class Scoping::FilterLogic < Scoping::Base
    include Scoping::Filterable

    GROUP_KINDS = %w[any all].freeze

    # Structural validation that doesn't require a resource. Checks node
    # shape (kind/of presence, array types, leaf arity). Filter/operator
    # validity is checked later in the instance #validate_tree!.
    def self.validate_structure!(node)
      unless node.is_a?(Hash) && (node.key?("kind") || node.key?(:kind))
        raise Errors::InvalidFilterLogicStructure.new("each node must have a 'kind' key")
      end

      kind = (node["kind"] || node[:kind]).to_s
      children = node["of"] || node[:of]

      unless children
        raise Errors::InvalidFilterLogicStructure.new("each node must have an 'of' key")
      end

      if GROUP_KINDS.include?(kind)
        unless children.is_a?(Array) && children.length >= 1
          raise Errors::InvalidFilterLogicStructure.new(
            "'#{kind}' node must have an 'of' array with at least 1 element"
          )
        end
        children.each { |child| validate_structure!(child) }
      else
        unless children.is_a?(Array) && children.length == 2
          raise Errors::InvalidFilterLogicStructure.new(
            "leaf node 'of' must have exactly 2 elements: [attribute, value]"
          )
        end
      end
    end

    def apply
      tree = query_hash[:filter_logic]
      return @scope unless tree

      validate_tree!(tree)
      @scope = build_scope(tree)
      resource.after_filtering(@scope)
    end

    # Public — adapters call this to process a single leaf node
    def process_leaf(scope, operator, children)
      attr_name = children[0].to_sym
      raw_value = children[1]
      filter = find_filter!(attr_name)
      value = coerce_and_validate_leaf(attr_name, raw_value)

      op_sym = operator.to_sym
      if (custom_scope = filter.values[0][:operators][op_sym])
        @resource.instance_exec(scope, value, resource.context, &custom_scope)
      else
        type_name = Types.name_for(filter.values.first[:type])
        method = :"filter_#{type_name}_#{op_sym}"
        resource.adapter.send(method, scope, attr_name, value)
      end
    end

    private

    def validate_tree!(node, depth = 1)
      kind = (node["kind"] || node[:kind]).to_s
      children = node["of"] || node[:of]

      if group_node?(kind)
        validate_group_node!(children, depth)
      else
        validate_leaf_node!(kind, children)
      end
    end

    def validate_group_node!(children, depth)
      max_depth = resource.class.filter_logic_max_depth

      if depth > max_depth
        raise Errors::FilterLogicDepthExceeded.new(max_depth)
      end

      children.each { |child| validate_tree!(child, depth + 1) }
    end

    def validate_leaf_node!(operator, children)
      attr_name = children[0].to_sym
      filter = find_filter!(attr_name)
      validate_operator(filter, operator.to_sym)
      coerce_and_validate_leaf(attr_name, children[1])
    end

    def coerce_and_validate_leaf(attr_name, raw_value)
      filter = find_filter!(attr_name)
      validate_singular(resource, filter, raw_value)
      value = coerce_filter_value(filter.values[0], attr_name, raw_value)
      validate_allowlist(resource, filter, value)
      validate_denylist(resource, filter, value)
      value = value[0] if filter.values[0][:single]
      value
    end

    def group_node?(kind)
      GROUP_KINDS.include?(kind.to_s)
    end

    def build_scope(tree)
      resource.adapter.apply_filter_logic_tree(@scope, tree, self)
    end
  end
end
