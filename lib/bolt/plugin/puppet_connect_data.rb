# frozen_string_literal: true

module Bolt
  class Plugin
    class PuppetConnectData
      INPUT_DATA_VAR = 'PUPPET_CONNECT_INPUT_DATA'

      def initialize(context:, **_opts)
        if ENV.key?(INPUT_DATA_VAR)
          # The user provided input data that they will copy-paste into the Puppet Connect UI
          # for inventory syncing. This environment variable will likely be set when invoking a
          # general "test Puppet Connect input data" command. That command tests that parsing
          # the inventory with the given input data results in connectable targets. Part of
          # that requires validating that the input data contains all of the referenced keys,
          # which is what this plugin will do in validate_resolve_reference.
          @input_data_path = ENV[INPUT_DATA_VAR]
          data_path = @input_data_path
        else
          # The user is using this plugin during a regular Bolt invocation, so fetch the (minimal)
          # required data from the default location. This data should typically be non-autoloadable
          # secrets like WinRM passwords.
          #
          # Note that any unspecified keys will be resolved to nil.
          data_path = File.join(context.boltdir, 'puppet_connect_data.yaml')
        end

        @data = Bolt::Util.read_optional_yaml_hash(
          data_path,
          File.basename(data_path)
        )

        if @input_data_path
          # Validate that the data does not contain any plugin-reference
          # values
          @data.each do |key, toplevel_value|
            # Use walk_vals to check for nested plugin references
            Bolt::Util.walk_vals(toplevel_value) do |current_value|
              if current_value.is_a?(Hash) && current_value.key?('_plugin')
                raise invalid_input_data_err("the #{key} key's value contains a plugin reference")
              end
              current_value
            end
          end
        end
      end

      def name
        'puppet_connect_data'
      end

      def hooks
        %i[resolve_reference validate_resolve_reference]
      end

      def resolve_reference(opts)
        key = opts['key']
        @data[key]
      end

      def validate_resolve_reference(opts)
        unless opts['key']
          raise Bolt::ValidationError,
                "puppet_connect_data plugin requires that 'key' be specified"
        end
        if @input_data_path && !@data.key?(opts['key'])
          # Input data for Puppet Connect was provided and opts['key'] does not have a
          # value specified. Raise an error for this case.
          raise invalid_input_data_err("a value for the #{opts['key']} key is not specified")
        end
      end

      def invalid_input_data_err(msg)
        Bolt::ValidationError.new("invalid input data #{@input_data_path}: #{msg}")
      end
    end
  end
end
