# frozen_string_literal: true

require 'json'

module Bolt
  class Plugin
    class Azure
      class AzureHTTPError < Bolt::Error
        def initialize(response)
          err = JSON.parse(response.body).dig('error', 'message')
          m = String.new("#{response.code} \"#{response.msg}\"")
          m += ": #{err}" if err
          super(m, 'bolt.plugin/azure-http-error')
        end
      end

      attr_reader :config

      CONFIG_KEYS = Set['tenant_id', 'client_id', 'client_secret', 'subscription_id', 'profile']
      OPTS_KEYS = Set['_plugin', 'location', 'tags', 'resource_group', 'scale_set'] + CONFIG_KEYS

      def initialize(config)
        validate_config(config)
        @config = config
        @logger = Logging.logger[self]
      end

      def name
        'azure'
      end

      def hooks
        %w[inventory_targets]
      end

      def validate_config(config)
        keys = config.keys.to_set

        unless CONFIG_KEYS.superset?(keys)
          keys -= CONFIG_KEYS
          raise Bolt::ValidationError, "Unexpected key(s) in plugin config: #{keys.to_a.inspect}"
        end
      end

      def validate_options(opts)
        keys = opts.keys.to_set

        unless OPTS_KEYS.superset?(keys)
          keys -= OPTS_KEYS
          raise Bolt::ValidationError, "Unexpected key(s) in inventory config: #{keys.to_a.inspect}"
        end
      end

      def inventory_targets(opts)
        validate_options(opts)
        creds = credentials(opts)
        token = token(creds)
        instances = instances(token, creds, opts)

        # Filter by location
        if opts['location']
          instances.select! do |instance|
            instance['location'] == opts['location']
          end
        end

        # Filter by tags - tags are ANDed
        if opts['tags']
          instances.select! do |instance|
            instance['tags'] && opts['tags'] <= instance['tags']
          end
        end

        # Map the VMs to a list of targets
        # name is set to the FQDN while uri is set to the public ip address
        # Any VMs that have neither of these set are dropped
        instances.map do |instance|
          target = {
            'name' => instance.dig('properties', 'dnsSettings', 'fqdn'),
            'uri' => instance.dig('properties', 'ipAddress')
          }.compact

          target unless target.empty?
        end.compact
      end

      # Hash of required credentials for authorizing with the Azure REST API
      # These values can be set in 3 locations - inventory config, Bolt config, environment variables
      # TODO: Add support for reading credentials from .ini file?
      def credentials(opts)
        creds = {
          'tenant_id' => (opts['tenant_id'] || config['tenant_id'] || ENV['AZURE_TENANT_ID']),
          'client_id' => (opts['client_id'] || config['client_id'] || ENV['AZURE_CLIENT_ID']),
          'client_secret' => (opts['client_secret'] || config['client_secret'] || ENV['AZURE_CLIENT_SECRET']),
          'subscription_id' => (opts['subscription_id'] || config['subscription_id'] || ENV['AZURE_SUBSCRIPTION_ID'])
        }

        # All credentials must be set, otherwise there's no point continuing
        if creds.values.include? nil
          keys = creds.select { |_, v| v.nil? }.keys
          raise Bolt::ValidationError, "Missing required credentials: #{keys}"
        end

        creds
      end

      # Requests for VMs and scale sets are on a per-subscription basis
      # You can also request VMs by a specific resource group
      # Scale sets are always requested by resource group and scale set name
      #
      # Since each request only returns up to 1,000 results, requests will continue to be
      # sent until there is no longer a nextLink token in the result set
      def instances(token, creds, opts)
        url = if opts['resource_group']
                if opts['scale_set']
                  "https://management.azure.com/subscriptions/#{creds['subscription_id']}/" \
                  "resourceGroups/#{opts['resource_group']}/providers/Microsoft.Compute/" \
                  "virtualMachineScaleSets/#{opts['scale_set']}/" \
                  "publicipaddresses?api-version=2017-03-30"
                else
                  "https://management.azure.com/subscriptions/#{creds['subscription_id']}/" \
                  "resourceGroups/#{opts['resource_group']}/providers/Microsoft.Network/" \
                  "publicIPAddresses?api-version=2019-06-01"
                end
              else
                "https://management.azure.com/subscriptions/#{creds['subscription_id']}/" \
                "providers/Microsoft.Network/publicIPAddresses?api-version=2019-06-01"
              end

        header = {
          'Authorization' => "#{token['token_type']} #{token['access_token']}"
        }

        instances = []

        while url do
          # Update the URI and make the next request
          uri = URI.parse(url)
          result = request(:Get, uri, nil, header)

          # Add the VMs to the list of instances
          instances << result['value']

          # Continue making requests until there is no longer a nextLink
          url = result['nextLink']
        end

        instances.flatten
      end

      # Uses the client credentials grant flow
      # https://docs.microsoft.com/en-us/azure/active-directory/develop/v1-oauth2-client-creds-grant-flow
      def token(creds)
        data = {
          grant_type: 'client_credentials',
          client_id: creds['client_id'],
          client_secret: creds['client_secret'],
          resource: 'https://management.azure.com'
        }

        uri = URI.parse("https://login.microsoftonline.com/#{creds['tenant_id']}/oauth2/token")

        request(:Post, uri, data)
      end

      def request(verb, uri, data, header = {})
        # Create the client
        client = Net::HTTP.new(uri.host, uri.port)

        # Azure REST API always uses SSL
        client.use_ssl = true
        client.verify_mode = OpenSSL::SSL::VERIFY_PEER

        # Build the request
        request = Net::HTTP.const_get(verb).new(uri.request_uri, header)

        # Build the query if there's data to send
        query = URI.encode_www_form(data) if data

        # Send the request
        begin
          response = client.request(request, query)
        rescue StandardError => e
          raise Bolt::Error.new(
            "Failed to connect to #{uri}: #{e.message}",
            'CONNECT_ERROR'
          )
        end

        case response
        when Net::HTTPOK
          JSON.parse(response.body)
        else
          raise AzureHTTPError, response
        end
      end
    end
  end
end
