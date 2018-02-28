#!/usr/bin/env ruby

require 'json'
require 'httpclient'
require 'optparse'
require 'yaml'

module Bolt
  class PuppetDBInventory
    class Client
      def self.from_config(config)
        uri = URI.parse(config['server_urls'].first)
        uri.port ||= 8081

        cacert = File.expand_path(config['cacert'])
        token = config.token

        cert = config['cert']
        key = config['key']

        new(uri, cacert, token: token, cert: cert, key: key)
      end

      def initialize(uri, cacert, token: nil, cert: nil, key: nil)
        @uri = uri
        @cacert = cacert
        @token = token
        @cert = cert
        @key = key
      end

      def query_certnames(query)
        return [] unless query

        body = JSON.generate(query: query)

        response = http_client.post("#{@uri}/pdb/query/v4", body: body, header: headers)
        if response.code != 200
          raise "Failed to query PuppetDB: #{response.body}"
        else
          results = JSON.parse(response.body)
          if results.first && !results.first.key?('certname')
            raise "Query results did not contain a 'certname' field: got #{results.first.keys.join(', ')}"
          end
          results.map { |result| result['certname'] }.uniq
        end
      end

      def http_client
        return @http if @http
        @http = HTTPClient.new
        @http.ssl_config.set_client_cert_file(@cert, @key)
        @http.ssl_config.add_trust_ca(@cacert)

        @http
      end

      def headers
        headers = { 'Content-Type' => 'application/json' }
        headers['X-Authentication'] = @token if @token
        headers
      end
    end

    class Config
      DEFAULT_TOKEN = File.expand_path('~/.puppetlabs/token')
      DEFAULT_CONFIG = File.expand_path('~/.puppetlabs/client-tools/puppetdb.conf')

      def initialize(config_file, options)
        @settings = load_config(config_file)
        @settings.merge!(options)

        expand_paths
        validate
      end

      def load_config(filename)
        if filename
          if File.exist?(filename)
            config = JSON.parse(File.read(filename))
          else
            raise "config file #{filename} does not exist"
          end
        elsif File.exist?(DEFAULT_CONFIG)
          config = JSON.parse(File.read(DEFAULT_CONFIG))
        else
          config = {}
        end
        config.fetch('puppetdb', {})
      end

      def token
        return @token if @token
        if @settings['token']
          File.read(@settings['token'])
        elsif File.exist?(DEFAULT_TOKEN)
          File.read(DEFAULT_TOKEN)
        end
      end

      def [](key)
        @settings[key]
      end

      def expand_paths
        %w[cacert cert key token].each do |file|
          @settings[file] = File.expand_path(@settings[file]) if @settings[file]
        end
      end

      def validate_file_exists(file)
        if @settings[file] && !File.exist?(@settings[file])
          raise "#{file} file #{@settings[file]} does not exist"
        end
      end

      def validate
        unless @settings['server_urls']
          raise "server_urls must be specified in the config file or with --url"
        end
        unless @settings['cacert']
          raise "cacert must be specified in the config file or with --cacert"
        end

        if (@settings['cert'] && !@settings['key']) ||
           (!@settings['cert'] && @settings['key'])
          raise "cert and key must be specified together"
        end

        validate_file_exists('cacert')
        validate_file_exists('cert')
        validate_file_exists('key')
      end
    end

    class CLI
      def initialize(args)
        @args = args
        @cli_opts = {}
        @parser = build_parser
      end

      def build_parser
        parser = OptionParser.new('') do |opts|
          opts.on('--cacert CACERT', "Path to the CA certificate") do |cacert|
            @cli_opts['cacert'] = cacert
          end
          opts.on('--cert CERT', "Path to the certificate") do |cert|
            @cli_opts['cert'] = cert
          end
          opts.on('--key KEY', "Path to the private key") do |key|
            @cli_opts['key'] = key
          end
          opts.on('--token-file TOKEN',
                  "Path to the token file",
                  "Default: #{Config::DEFAULT_TOKEN} if present") do |token|
            @cli_opts['token'] = token
          end
          opts.on('--url URL', "The URL of the PuppetDB server to connect to") do |url|
            @cli_opts['server_urls'] = [url]
          end
          opts.on('--config CONFIG',
                  "The puppetdb.conf file to read configuration from",
                  "Default: #{Config::DEFAULT_CONFIG} if present") do |file|
            @config_file = File.expand_path(file)
          end
          opts.on('--output FILE', '-o FILE',
                  "Where to write the generated inventory file, defaults to stdout") do |file|
            @output_file = file
          end
          opts.on('--trace', "Show stacktraces for exceptions") do |trace|
            @trace = trace
          end
          opts.on('-h', '--help', "Display help") do |_|
            @show_help = true
          end
        end
        parser.banner = <<-BANNER
Usage: bolt-inventory-pdb <input-file> [--output <output-file>] [--url <url>] [auth-options]

Populate the nodes in an inventory file based on PuppetDB queries.

The input file should be a Bolt inventory file, where each 'nodes' entry is
replaced with a 'query' entry to be executed against PuppetDB. The output will
be the input file, with the 'nodes' entry for each group populated with the
query results.

        BANNER
        parser
      end

      def run
        positional_args = @parser.permute(@args)

        if @show_help
          puts @parser.help
          return 0
        end

        inventory_file = positional_args.shift
        unless inventory_file
          raise "Please specify an input file (see --help for details)"
        end

        if positional_args.any?
          raise "Unknown argument(s) #{positional_args.join(', ')}"
        end

        config = Config.new(@config_file, @cli_opts)
        @puppetdb_client = Client.from_config(config)

        unless File.readable?(inventory_file)
          raise "Can't read the inventory file #{inventory_file}"
        end

        inventory = YAML.load_file(inventory_file)
        resolve_group(inventory)

        result = inventory.to_yaml

        if @output_file
          File.write(@output_file, result)
        else
          puts result
        end

        return 0
      rescue StandardError => e
        puts "Error: #{e}"
        puts e.backtrace if @trace
        return 1
      end

      def resolve_group(group)
        group['nodes'] = @puppetdb_client.query_certnames(group['query'])

        group.fetch('groups', []).each do |child|
          resolve_group(child)
        end

        group
      end
    end
  end
end
