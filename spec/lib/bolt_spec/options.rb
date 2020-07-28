# frozen_string_literal: true

module BoltSpec
  module Options
    # This function is used to ensure that every config option
    # has a :type and :description key, as they are required for
    # generating the JSON schemas and validating config.
    def assert_type_description(definitions)
      definitions.each do |option, definition|
        expect(definition.key?(:description)).to be, "missing :description key for option '#{option}'"
        expect(definition.key?(:type)).to be, "missing :type key for option '#{option}'"

        if definition.key?(:properties)
          expect(definition[:properties].class).to eq(Hash), ":properties key for option '#{option}' must be a Hash"
          assert_type_description(definition[:properties])
        end

        %i[additionalProperties items].each do |key|
          next unless definition.key?(key)
          expect(definition[key].class).to eq(Hash), ":#{key} key for option '#{option}' must be a Hash"
          expect(definition[key].key?(:type)).to be, "missing :type key for :#{key} in option '#{option}'"
        end
      end
    end
  end
end
