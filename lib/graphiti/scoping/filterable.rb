module Graphiti
  # @api private
  module Scoping::Filterable
    # @api private
    def find_filter(name)
      find_filter!(name)
    rescue Graphiti::Errors::AttributeError
      nil
    end

    # @api private
    def find_filter!(name)
      resource.class.get_attr!(name, :filterable, request: true)
      {name => resource.filters[name]}
    end

    # @api private
    def filter_param
      query_hash[:filter] || {}
    end

    def missing_required_filters
      required_filters - filter_param.keys
    end

    def required_filters
      resource.filters.map { |k, v|
        k if v[:required]
      }.compact
    end

    def missing_dependent_filters
      [].tap do |arr|
        filter_param.each_pair do |key, value|
          if (df = dependent_filters[key])
            missing = df[:dependencies] - filter_param.keys
            unless missing.length.zero?
              arr << {filter: df, missing: missing}
            end
          end
        end
      end
    end

    def dependent_filters
      resource.filters.select do |k, v|
        v[:dependencies].present?
      end
    end

    def coerce_filter_value(filter_config, name, value)
      type_name = filter_config[:type]
      is_array = type_name.to_s.starts_with?("array_of") ||
        Graphiti::Types[type_name][:canonical_name] == :array

      if is_array
        @resource.typecast(name, value, :filterable)
      else
        value = value.nil? || value.is_a?(Hash) ? [value] : Array(value)
        value.map { |v| @resource.typecast(name, v, :filterable) }
      end
    end

    def validate_allowlist(resource, filter, values)
      Array(values).each do |v|
        if (allow = filter.values[0][:allow])
          unless allow.include?(v)
            raise Graphiti::Errors::InvalidFilterValue.new(resource, filter, v)
          end
        end
      end
    end

    def validate_denylist(resource, filter, values)
      Array(values).each do |v|
        if (deny = filter.values[0][:deny])
          if deny.include?(v)
            raise Graphiti::Errors::InvalidFilterValue.new(resource, filter, v)
          end
        end
      end
    end

    def validate_singular(resource, filter, value)
      if filter.values[0][:single] && value.is_a?(Array)
        raise Graphiti::Errors::SingularFilter.new(resource, filter, value)
      end
    end
  end
end
