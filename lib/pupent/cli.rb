# frozen_string_literal: true

require_relative '../pupent/pupent_option_parser'
require_relative '../pupent/config'
require_relative '../pupent/http_client'
require_relative '../pupent/access'
require_relative '../pupent/code'

module PupEnt
  class CLI
    def initialize(argv)
      @command, @action, @object, cli_options = PupEntOptionParser.parse(argv)
      # This merge is done in a specific order on purpose:
      #
      # The final parsed options are read from the config options on disk first, then
      # we merge anything sent over the CLI. This forces the precedence that CLI options
      # override anything set on disk.
      @parsed_options = Config.read_config(cli_options[:config_file]).merge(cli_options)
      Bolt::Logger.initialize_logging
      Bolt::Logger.logger(:root).add_appenders Logging.appenders.stderr(
        'console',
        layout: Bolt::Logger.console_layout(true),
        level: @parsed_options[:log_level]
      )
      @pe_host_url = parse_pe_host_url(@command, @parsed_options[:pe_host], @parsed_options[:service_url])
      @ca_cert = @parsed_options[:ca_cert]
      if @parsed_options[:save_config]
        require_relative '../pupent/config'
        Config.save_config(@parsed_options)
      end
    end

    def parse_pe_host_url(command, pe_host, service_url)
      if pe_host
        case command
        when 'access'
          "https://" + pe_host + Access::RBAC_PREFIX
        when 'code'
          "https://" + pe_host + Code::CODE_MANAGER_PREFIX
        end
      elsif service_url
        service_url
      end
    end

    # Only create a client when we need to
    def new_client
      HttpClient.new(@pe_host_url, @ca_cert)
    end

    def execute
      case @command
      when 'access'
        case @action
        when 'login'
          Access.new(
            @parsed_options[:token_file]
          ).login(new_client, @parsed_options[:lifetime])
          0
        when 'list'
          $stdout.puts Access.new(
            @parsed_options[:token_file]
          ).list(new_client)
          0
        when 'show'
          $stdout.puts Access.new(@parsed_options[:token_file]).show
          0
        when 'delete-token-file'
          Access.new(@parsed_options[:token_file]).delete_token
          0
        end
      when 'code'
        case @action
        when 'deploy'
          $stdout.puts Code.new(
            @parsed_options[:token_file],
            new_client
          ).deploy(@object, @parsed_options[:wait], @parsed_options[:all])
          0
        when 'status'
          $stdout.puts Code.new(
            @parsed_options[:token_file],
            new_client
          ).status
          0
        when 'deploy-status'
          $stdout.puts Code.new(
            @parsed_options[:token_file],
            new_client
          ).deploy_status(@object)
          0
        end
      end
    end
  end
end
