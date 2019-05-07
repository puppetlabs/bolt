# frozen_string_literal: true

require 'json'

module Bolt
  class Plugin
    class Terraform
      def name
        'terraform'
      end

      def hooks
        ['lookup_targets']
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
        end.map do |_name, resource|
          target = { 'uri' => resource[opts['uri']] }
          if opts.key?('name')
            target['name'] = resource[opts['name']]
          end
          if opts.key?('config')
            target['config'] = resolve_config(resource, opts['config'])
          end
          target
        end
      end

      def load_statefile(opts)
        dir = opts['dir']
        filename = opts.fetch('statefile', 'terraform.tfstate')
        statefile = File.expand_path(File.join(dir, filename))

        JSON.parse(File.read(statefile))
      rescue StandardError => e
        raise Bolt::FileError.new("Could not load Terraform state file #{filename}: #{e}", filename)
      end

      def resolve_config(resource, config_template)
        Bolt::Util.walk_vals(config_template) do |value|
          if value.is_a?(String)
            resource[value]
          else
            value
          end
        end
      end
    end
  end
end
