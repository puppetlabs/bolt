# frozen_string_literal: true

require 'bolt/error'

# This class validates config against a schema, raising an error that includes
# details about any invalid configuration.
#
module Bolt
  class Config
    class Validator
      def initialize
        @errors = []
        @path   = []
      end

      # This is the entry method for validating data against the schema.
      # It loops over each key-value pair in the data hash and validates
      # the value against the relevant schema definition.
      #
      def validate(data, schema, location = nil)
        data.each_pair do |key, value|
          next unless schema.key?(key)

          @path.push(key)
          validate_value(value, schema[key])
        ensure
          @path.pop
        end

        raise_error(location)
      end

      # Raises a ValidationError if there are any errors. All error messages
      # created during validation are concatenated into a single error
      # message.
      #
      private def raise_error(location)
        return unless @errors.any?

        message = "Invalid configuration"
        message += " at #{location}" if location
        message += ":\n"
        message += @errors.map { |error| "\s\s#{error}" }.join("\n")

        raise Bolt::ValidationError, message
      end

      # Validate an individual value. This performs validation that is
      # common to all values, including type validation. After validating
      # the value's type, the value is passed off to an individual
      # validation method for the value's type.
      #
      private def validate_value(value, definition)
        return if plugin_reference?(value, definition)
        return unless valid_type?(value, definition)

        case value
        when Hash
          validate_hash(value, definition)
        when Array
          validate_array(value, definition)
        when String
          validate_string(value, definition)
        when Numeric
          validate_number(value, definition)
        end
      end

      # Validates a hash value, logging errors for any validations that fail.
      # This will enumerate each key-value pair in the hash and validate each
      # value individually.
      #
      private def validate_hash(value, definition)
        properties = definition[:properties] ? definition[:properties].keys : []

        if definition[:required] && (definition[:required] - value.keys).any?
          missing = definition[:required] - value.keys
          @errors << "Value at '#{path}' is missing required keys #{missing.join(', ')}"
        end

        value.each_pair do |key, val|
          @path.push(key)

          if properties.include?(key)
            validate_value(val, definition[:properties][key])
          elsif definition[:additionalProperties]
            validate_value(val, definition[:additionalProperties])
          end
        ensure
          @path.pop
        end
      end

      # Validates an array value, logging errors for any validations that fail.
      # This will enumerate the items in the array and validate each item
      # individually.
      #
      private def validate_array(value, definition)
        if definition[:uniqueItems] && value.size != value.uniq.size
          @errors << "Value at '#{path}' must not include duplicate elements"
          return
        end

        return unless definition.key?(:items)

        value.each_with_index do |item, index|
          @path.push(index)
          validate_value(item, definition[:items])
        ensure
          @path.pop
        end
      end

      # Validates a string value, logging errors for any validations that fail.
      #
      private def validate_string(value, definition)
        if definition.key?(:enum) && !definition[:enum].include?(value)
          @errors << "Value at '#{path}' must be one of #{definition[:enum].join(', ')}"
        end
      end

      # Validates a numeric value, logging errors for any validations that fail.
      #
      private def validate_number(value, definition)
        if definition.key?(:minimum) && value < definition[:minimum]
          @errors << "Value at '#{path}' must be a minimum of #{definition[:minimum]}"
        end
      end

      # Returns true if a value is a plugin reference. This also validates whether
      # a value can be a plugin reference in the first place. If the value is a
      # plugin reference but cannot be one according to the schema, then this will
      # log an error.
      #
      private def plugin_reference?(value, definition)
        if value.is_a?(Hash) && value.key?('_plugin')
          unless definition[:_plugin]
            @errors << "Value at '#{path}' is a plugin reference, which is unsupported at "\
                       "this location"
          end

          true
        else
          false
        end
      end

      # Asserts the type for each option against the type specified in the schema
      # definition. The schema definition can specify multiple valid types, so the
      # value needs to only match one of the types to be valid. Returns early if
      # there is no type in the definition (in practice this shouldn't happen, but
      # this will safeguard against any dev mistakes).
      #
      private def valid_type?(value, definition)
        return unless definition.key?(:type)

        types = Array(definition[:type])

        if types.include?(value.class)
          true
        else
          if types.include?(TrueClass) || types.include?(FalseClass)
            types = types - [TrueClass, FalseClass] + ['Boolean']
          end

          @errors << "Value at '#{path}' must be of type #{types.join(', ')}"

          false
        end
      end

      # Returns the formatted path for the key.
      #
      private def path
        @path.join('.')
      end
    end
  end
end
