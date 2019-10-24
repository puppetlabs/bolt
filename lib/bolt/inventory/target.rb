# frozen_string_literal: true

module Bolt
  class Inventory
    # This class represents the active state of a target within the inventory.
    class Target
      attr_reader :name, :uri, :safe_name

      def initialize(target_data, inventory)
        unless target_data['name'] || target_data['uri']
          raise Bolt::Inventory::ValidationError.new("Target must have either a name or uri", nil)
        end

        @logger = Logging.logger[inventory]

        # If the target isn't mentioned by any groups, it won't have a uri or
        # name and we will use the target_name as both
        @uri = target_data['uri']
        @uri_obj = self.class.parse_uri(@uri)

        # If the target has a name, use that as the safe name. Otherwise, turn
        # the uri into a safe name by omitting the password.
        if target_data['name']
          @name = target_data['name']
          @safe_name = target_data['name']
        else
          @name = @uri
          @safe_name = @uri_obj.omit(:password).to_str.sub(%r{^//}, '')
        end

        @config = target_data['config'] || {}
        @vars = target_data['vars'] || {}
        @facts = target_data['facts'] || {}
        @features = target_data['features'] || Set.new
        @options = target_data['options'] || {}
        @plugin_hooks = target_data['plugin_hooks'] || {}
        @target_alias = target_data['target_alias'] || []

        @inventory = inventory

        validate
      end

      def vars
        # XXX Return vars from the cache
        group_cache['vars'].merge(@vars)
      end

      # This method isn't actually an accessor and we want the name to
      # correspond to the Puppet function
      # rubocop:disable Naming/AccessorMethodName
      def set_var(var_hash)
        @vars.merge!(var_hash)
      end
      # rubocop:enable Naming/AccessorMethodName

      def facts
        # XXX Return facts from the cache
        Bolt::Util.deep_merge(group_cache['facts'], @facts)
      end

      def add_facts(new_facts = {})
        @facts = Bolt::Util.deep_merge(@facts, new_facts)
      end

      def features
        group_cache['features'] + @features
      end

      def set_feature(feature, value = true)
        if value
          @features << feature
        else
          @features.delete(feature)
        end
      end

      def plugin_hooks
        # Merge plugin_hooks from the config file with any defined by the group
        # or assigned dynamically to the target
        @inventory.config.plugin_hooks.merge(group_cache['plugin_hooks']).merge(@plugin_hooks)
      end

      def set_config(key_or_key_path, value)
        if key_or_key_path.empty?
          @config = value
        else
          *path, key = Array(key_or_key_path)
          location = path.inject(@config) do |working_object, p|
            working_object[p] ||= {}
          end
          location[key] = value
        end
        invalidate_config_cache!
      end

      def invalidate_group_cache!
        @group_cache = nil
        # The config cache depends on the group cache, so invalidate it as well
        invalidate_config_cache!
      end

      def invalidate_config_cache!
        @transport_config_cache = nil
      end

      # Computing the transport config is expensive as it requires cloning the
      # base config, so we cache the effective config
      def transport_config_cache
        if @transport_config_cache.nil?
          merged_config = Bolt::Util.deep_merge(group_cache['config'], @config)
          # Use the base config to ensure we handle the config validation and
          # munging correctly
          config = @inventory.config.deep_clone
          config.update_from_inventory(merged_config)
          config.validate
          @transport_config_cache = {
            'transport' => config.transport_conf[:transport],
            'transports' => config.transport_conf[:transports]
          }
        end

        @transport_config_cache
      end

      # Validate the target. This implicitly also primes the group and config
      # caches and resolves any config references in the target's groups.
      def validate
        unless name.ascii_only?
          raise Bolt::Inventory::ValidationError.new("Target name must be ASCII characters: #{@name}", nil)
        end

        unless transport.nil? || Bolt::TRANSPORTS.include?(transport.to_sym)
          raise Bolt::UnknownTransportError.new(transport, uri)
        end
      end

      def host
        @uri_obj.hostname || transport_config['host']
      end

      def port
        @uri_obj.port || transport_config['port']
      end

      def protocol
        transport
      end

      def transport
        @uri_obj.scheme || transport_config_cache['transport']
      end

      def user
        Addressable::URI.unencode_component(@uri_obj.user) || transport_config['user']
      end

      def password
        Addressable::URI.unencode_component(@uri_obj.password) || transport_config['password']
      end

      def options
        transport_config.dup
      end

      # We only want to look up transport config keys for the configured
      # transport
      def transport_config
        transport_config_cache['transports'][transport.to_sym]
      end

      def config
        Bolt::Util.deep_merge(group_cache['config'], @config)
      end

      def group_cache
        if @group_cache.nil?
          group_data = @inventory.group_data_for(@name)

          unless group_data && group_data['config']
            @logger.debug("Did not find config for #{self} in inventory")
          end

          group_data ||= {
            'config' => {},
            'vars' => {},
            'facts' => {},
            'features' => Set.new,
            'options' => {},
            'plugin_hooks' => {},
            'target_alias' => []
          }

          # This should be handled by `get_targets`
          if @name == 'localhost'
            group_data = Bolt::Inventory.localhost_defaults(group_data)
          end

          @group_cache = group_data
        end

        @group_cache
      end

      def to_s
        @safe_name
      end

      def self.parse_uri(string)
        require 'addressable/uri'
        if string.nil?
          Addressable::URI.new
        # Forbid empty uri
        elsif string.empty?
          raise Bolt::ParseError, "Could not parse target URI: URI is empty string"
        elsif string =~ %r{^[^:]+://}
          Addressable::URI.parse(string)
        else
          # Initialize with an empty scheme to ensure we parse the hostname correctly
          Addressable::URI.parse("//#{string}")
        end
      rescue Addressable::URI::InvalidURIError => e
        raise Bolt::ParseError, "Could not parse target URI: #{e.message}"
      end
    end
  end
end
