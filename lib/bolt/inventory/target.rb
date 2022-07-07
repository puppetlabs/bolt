# frozen_string_literal: true

require_relative '../../bolt/resource_instance'

module Bolt
  class Inventory
    # This class represents the active state of a target within the inventory.
    class Target
      attr_reader :name, :uri, :safe_name, :target_alias, :resources

      # Illegal characters that are not permitted in target names.
      # These characters are delimiters for target and group names and allowing
      # them would cause unexpected behavior.
      ILLEGAL_CHARS = /[\s,]/.freeze

      def initialize(target_data, inventory)
        unless target_data['name'] || target_data['uri']
          raise Bolt::Inventory::ValidationError.new("Target must have either a name or uri", nil)
        end

        @logger = Bolt::Logger.logger(inventory)

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

        if @name == 'localhost'
          default = { 'config' => { 'transport' => 'local' } }
          target_data = Bolt::Util.deep_merge(default, target_data)
        end

        @config = target_data['config'] || {}
        @vars = target_data['vars'] || {}
        @facts = target_data['facts'] || {}
        @features = target_data['features'] || Set.new
        @plugin_hooks = target_data['plugin_hooks'] || {}
        # When alias is specified in a plan, the key will be `target_alias`, when
        # alias is specified in inventory the key will be `alias`.
        @target_alias = target_data['target_alias'] || target_data['alias'] || []
        @resources = {}

        @inventory = inventory

        validate
      end

      def set_local_defaults
        return if @set_local_default
        defaults = {
          'local' => { 'interpreters' => { '.rb' => RbConfig.ruby } }
        }
        old_config = @config
        @config = Bolt::Util.deep_merge(defaults, @config)
        invalidate_config_cache! if old_config != @config
        set_feature('puppet-agent')
        @set_local_default = true
      end

      # rubocop:disable Naming/AccessorMethodName
      def set_resource(resource)
        if (existing_resource = resources[resource.reference])
          existing_resource.overwrite_state(resource.state)
          existing_resource.overwrite_desired_state(resource.desired_state)
          existing_resource.events = existing_resource.events + resource.events
          existing_resource
        else
          @resources[resource.reference] = resource
        end
      end
      # rubocop:enable Naming/AccessorMethodName

      def vars
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
        Bolt::Util.deep_merge(group_cache['facts'], @facts)
      end

      def add_facts(new_facts = {})
        validate_fact_names(new_facts)
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

      def resource(type, title)
        resources[Bolt::ResourceInstance.format_reference(type, title)]
      end

      def plugin_hooks
        # Merge plugin_hooks from the config file with any defined by the group
        # or assigned dynamically to the target
        @inventory.plugins.plugin_hooks.merge(group_cache['plugin_hooks']).merge(@plugin_hooks)
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
        @transport = nil
        @transport_config = nil
      end

      # Validate the target. This implicitly also primes the group and config
      # caches and resolves any config references in the target's groups.
      def validate
        unless name.ascii_only?
          raise Bolt::Inventory::ValidationError.new("Target name must be ASCII characters: #{@name}", nil)
        end

        if (illegal_char = @name.match(ILLEGAL_CHARS))
          raise ValidationError.new("Illegal character '#{illegal_char}' in target name '#{@name}'", nil)
        end

        unless transport.nil? || Bolt::TRANSPORTS.include?(transport.to_sym)
          raise Bolt::UnknownTransportError.new(transport, uri)
        end

        validate_fact_names(facts)

        transport_config
      end

      # Validate fact names and issue a deprecation warning if any fact names have a dot.
      #
      private def validate_fact_names(facts)
        if (dotted = facts.keys.select { |name| name.include?('.') }).any?
          Bolt::Logger.deprecate(
            'dotted_fact_name',
            "Target '#{safe_name}' includes dotted fact names: '#{dotted.join("', '")}'. Dotted fact "\
            "names are deprecated and Bolt does not automatically convert facts with dotted names to "\
            "structured facts. For more information, see https://pup.pt/bolt-dotted-facts"
          )
        end
      end

      def host
        @uri_obj.hostname || transport_config['host']
      end

      def port
        @uri_obj.port || transport_config['port']
      end

      # For remote targets, protocol is the value of the URI scheme. For
      # non-remote targets, there is no protocol.
      def protocol
        if remote?
          @uri_obj.scheme
        end
      end

      # For remote targets, the transport is always 'remote'. Otherwise, it
      # will be either the URI scheme or set explicitly.
      def transport
        if @transport.nil?
          config_transport = @config['transport'] ||
                             group_cache.dig('config', 'transport') ||
                             @inventory.transport

          @transport = if @uri_obj.scheme == 'remote' || config_transport == 'remote'
                         'remote'
                       else
                         @uri_obj.scheme || config_transport
                       end
        end

        @transport
      end

      def remote?
        transport == 'remote'
      end

      def user
        Addressable::URI.unencode_component(@uri_obj.user) || transport_config['user']
      end

      def password
        Addressable::URI.unencode_component(@uri_obj.password) || transport_config['password']
      end

      # We only want to look up transport config keys for the configured
      # transport
      def transport_config
        if @transport_config.nil?
          config = @inventory.config[transport]
                             .merge(group_cache.dig('config', transport), @config[transport])
          @transport_config = config
        end

        @transport_config
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
            'plugin_hooks' => {},
            'target_alias' => []
          }

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
