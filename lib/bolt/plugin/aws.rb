# frozen_string_literal: true

require 'json'

module Bolt
  class Plugin
    class Aws
      class EC2
        attr_accessor :client
        attr_reader :config

        def initialize(config)
          require 'aws-sdk-ec2'
          @config = config
          @logger = Logging.logger[self]
        end

        def name
          'aws::ec2'
        end

        def hooks
          %w[inventory_targets]
        end

        def config_client(opts)
          return client if client

          options = {}

          if opts.key?('region')
            options[:region] = opts['region']
          end
          if opts.key?('profile')
            options[:profile] = opts['profile']
          end
          if config['credentials']
            creds = File.expand_path(config['credentials'])
            if File.exist?(creds)
              options[:credentials] = ::Aws::SharedCredentials.new(path: creds)
            else
              raise Bolt::ValidationError, "Cannot load credentials file #{config['credentials']}"
            end
          end

          ::Aws::EC2::Client.new(options)
        end

        def inventory_targets(opts)
          client = config_client(opts)
          resource = ::Aws::EC2::Resource.new(client: client)

          # Retrieve a list of EC2 instances and create a list of targets
          # Note: It doesn't seem possible to filter stubbed responses...
          resource.instances(filters: opts['filters']).map do |instance|
            next unless instance.state.name == 'running'
            target = {}

            if opts.key?('uri')
              uri = lookup(instance, opts['uri'])
              target['uri'] = uri if uri
            end
            if opts.key?('name')
              real_name = lookup(instance, opts['name'])
              target['name'] = real_name if real_name
            end
            if opts.key?('config')
              target['config'] = resolve_config(instance, opts['config'])
            end

            target if target['uri'] || target['name']
          end.compact
        end

        # Look for an instance attribute specified in the inventory file
        def lookup(instance, attribute)
          value = instance.data.respond_to?(attribute) ? instance.data[attribute] : nil
          unless value
            warn_missing_attribute(instance, attribute)
          end
          value
        end

        def warn_missing_attribute(instance, attribute)
          @logger.warn("Could not find attribute #{attribute} of instance #{instance.instance_id}")
        end

        # Walk the "template" config mapping provided in the plugin config and
        # replace all values with the corresponding value from the resource
        # parameters.
        def resolve_config(name, config_template)
          Bolt::Util.walk_vals(config_template) do |value|
            if value.is_a?(String)
              lookup(name, value)
            else
              value
            end
          end
        end
      end
    end
  end
end
