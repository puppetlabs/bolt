# frozen_string_literal: true

require 'json'

module Bolt
  class Plugin
    class Terraform
      def initialize
        @logger = Logging.logger[self]
      end

      def name
        'terraform'
      end

      def hooks
        ['lookup_targets']
      end

      def warn_missing_property(name, property)
        @logger.warn("Could not find property #{property} of terraform resource #{name}")
      end

      def lookup_targets(opts)
        state = load_statefile(opts)

        resources = state.fetch('modules', {}).flat_map do |mod|
          mod.fetch('resources', {}).map do |name, resource|
            [name, resource.dig('primary', 'attributes')]
          end
        end

        regex = Regexp.new(opts['resource_type'])

        resources.select do |name, _resource|
          name.match?(regex)
        end.map do |name, resource|
          unless resource.key?(opts['uri'])
            warn_missing_property(name, opts['uri'])
            next
          end

          target = { 'uri' => resource[opts['uri']] }
          if opts.key?('name')
            if resource.key?(opts['name'])
              target['name'] = resource[opts['name']]
            else
              warn_missing_property(name, opts['name'])
            end
          end
          if opts.key?('config')
            target['config'] = resolve_config(name, resource, opts['config'])
          end
          target
        end.compact
      end

      def load_statefile(opts)
        dir = opts['dir']
        filename = opts.fetch('statefile', 'terraform.tfstate')
        statefile = File.expand_path(File.join(dir, filename))

        JSON.parse(File.read(statefile))
      rescue StandardError => e
        raise Bolt::FileError.new("Could not load Terraform state file #{filename}: #{e}", filename)
      end

      def resolve_config(name, resource, config_template)
        Bolt::Util.walk_vals(config_template) do |value|
          if value.is_a?(String)
            if resource.key?(value)
              resource[value]
            else
              warn_missing_property(name, value)
              nil
            end
          else
            value
          end
        end
      end
    end
  end
end
