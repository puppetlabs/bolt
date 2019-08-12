# frozen_string_literal: true

require 'json'

module Bolt
  class Plugin
    class Terraform
      KNOWN_KEYS = Set['_plugin', 'dir', 'resource_type', 'uri', 'name', 'statefile',
                       'config', 'backend']
      REQ_KEYS = Set['dir', 'resource_type']

      def initialize
        @logger = Logging.logger[self]
      end

      def name
        'terraform'
      end

      def hooks
        ['inventory_targets']
      end

      def warn_missing_property(name, property)
        @logger.warn("Could not find property #{property} of terraform resource #{name}")
      end

      # Make sure no unexpected keys are in the inventory config and
      # that required keys are present
      def validate_options(opts)
        opt_keys = opts.keys.to_set

        unless KNOWN_KEYS.superset?(opt_keys)
          keys = opt_keys - KNOWN_KEYS
          raise Bolt::ValidationError, "Unexpected key(s) in inventory config: #{keys.to_a.inspect}"
        end

        unless opt_keys.superset?(REQ_KEYS)
          keys = REQ_KEYS - opt_keys
          raise Bolt::ValidationError, "Expected key(s) in inventory config: #{keys.to_a.inspect}"
        end
      end

      def inventory_targets(opts)
        validate_options(opts)

        state = load_statefile(opts)

        resources = extract_resources(state)

        regex = Regexp.new(opts['resource_type'])

        resources.select do |name, _resource|
          name.match?(regex)
        end.map do |name, resource|
          target = {}

          if opts.key?('uri')
            uri = lookup(name, resource, opts['uri'])
            target['uri'] = uri if uri
          end
          if opts.key?('name')
            real_name = lookup(name, resource, opts['name'])
            target['name'] = real_name if real_name
          end
          if opts.key?('config')
            target['config'] = resolve_config(name, resource, opts['config'])
          end
          target
        end.compact
      end

      def load_statefile(opts)
        statefile = if opts['backend'] == 'remote'
                      load_remote_statefile(opts)
                    else
                      load_local_statefile(opts)
                    end

        JSON.parse(statefile)
      end

      # Uses the Terraform CLI to pull remote state files
      def load_remote_statefile(opts)
        stdout_str, stderr_str, = Open3.capture3('terraform state pull', chdir: opts['dir'])

        unless stderr_str.empty?
          err = stdout_str.split("\n").first
          msg = "Could not pull Terraform remote state file for #{opts['dir']}: #{err}"
          raise Bolt::Error.new(msg, 'bolt/terraform-state-error')
        end

        stdout_str
      end

      def load_local_statefile(opts)
        dir = opts['dir']
        filename = opts.fetch('statefile', 'terraform.tfstate')
        File.read(File.expand_path(File.join(dir, filename)))
      rescue StandardError => e
        raise Bolt::FileError.new("Could not load Terraform state file #{filename}: #{e}", filename)
      end

      # Format the list of resources into a list of [name, attribute map]
      # pairs. This method handles both version 4 and earlier statefiles, doing
      # the appropriate munging based on the shape of the data.
      def extract_resources(state)
        if state['version'] >= 4
          state.fetch('resources', []).flat_map do |resource_set|
            prefix = "#{resource_set['type']}.#{resource_set['name']}"
            resource_set['instances'].map do |resource|
              instance_name = prefix
              instance_name += ".#{resource['index_key']}" if resource['index_key']
              # When using `terraform state pull` with terraform >= 0.12 version 3 statefiles
              # Will be converted to version 4. When converted attributes is converted to attributes_flat
              attributes = resource['attributes'] || resource['attributes_flat']
              [instance_name, attributes]
            end
          end
        else
          state.fetch('modules', {}).flat_map do |mod|
            mod.fetch('resources', {}).map do |name, resource|
              [name, resource.dig('primary', 'attributes')]
            end
          end
        end
      end

      # Look up a nested value from the resource attributes. The key is of the
      # form `foo.bar.0.baz`. For terraform statefile version 3, this will
      # exactly correspond to a key in the resource. In version 4, it will
      # correspond to a nested hash entry at {foo: {bar: [{baz: <value>}]}}
      # For simplicity's sake, we just check both.
      def lookup(name, resource, path)
        segments = path.split('.').map do |segment|
          begin
            Integer(segment)
          rescue ArgumentError
            segment
          end
        end

        value = resource[path] || resource.dig(*segments)
        unless value
          warn_missing_property(name, path)
        end
        value
      end

      # Walk the "template" config mapping provided in the plugin config and
      # replace all values with the corresponding value from the resource
      # parameters.
      def resolve_config(name, resource, config_template)
        Bolt::Util.walk_vals(config_template) do |value|
          if value.is_a?(String)
            lookup(name, resource, value)
          else
            value
          end
        end
      end
    end
  end
end
