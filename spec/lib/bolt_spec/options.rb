# frozen_string_literal: true

module BoltSpec
  module Options
    # This function is used to ensure that every config option
    # has a :type and :description key, as they are required for
    # generating the JSON schemas and validating config.
    def assert_type_description(definitions)
      definitions.each_pair do |option, definition|
        expect(definition.key?(:description)).to be, "missing :description key for option '#{option}'"
        expect(definition.key?(:type)).to be, "missing :type key for option '#{option}'"

        if definition.key?(:properties)
          msg = ":properties key for option '#{option}' must be a Hash"
          expect(definition[:properties].class).to eq(Hash), msg

          assert_type_description(definition[:properties])
        end

        if definition.key?(:additionalProperties)
          addtl_prop_types = [TrueClass, FalseClass, Hash]
          klass = definition[:additionalProperties].class
          msg = ":additionalProperties key for option '#{option}' must be a Hash or Boolean"
          expect(addtl_prop_types).to include(klass), msg

          if klass.is_a?(Hash)
            msg = "missing :type key for :additionalProperties in option '#{option}'"
            expect(definition[:additionalProperties].key?(:type)).to be, msg
          end
        end

        next unless definition.key?(:items)
        msg = ":items key for option '#{option}' must be a Hash"
        expect(definition[:items].class).to eq(Hash), msg

        msg = "missing :type key for :items in option '#{option}'"
        expect(definition[:items].key?(:type)).to be, msg
      end
    end
  end
end
