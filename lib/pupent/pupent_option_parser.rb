# frozen_string_literal: true

require 'optparse'
require_relative '../bolt/version'

module PupEnt
  class CLIExit < StandardError; end

  module PupEntOptionParser
    COLORS = {
      dim:    "2", # Dim, the other color of the rainbow
      red:    "31",
      green:  "32",
      yellow: "33",
      cyan:   "36"
    }.freeze

    def self.colorize(color, string)
      if $stdout.isatty
        "\033[#{COLORS[color]}m#{string}\033[0m"
      else
        string
      end
    end

    ALL_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
        pupent

      #{colorize(:cyan, 'Usage')}
        pupent <subcommand> [action] [options]

      #{colorize(:cyan, 'Description')}
        pupent is a cli helper included with Bolt that provides access on the command line
        to various functions of Puppet Enterprise

      #{colorize(:cyan, 'Subcommands')}
        access          PE token management
        code            Remote puppet code management

      #{colorize(:cyan, 'Options')}
    HELP

    CODE_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
        code

      #{colorize(:cyan, 'Usage')}
        pupent code [action] [options]

      #{colorize(:cyan, 'Actions')}
        deploy          Runs remote code deployments
        help            Help about any command
        print-config    Prints out the resolved pupent configuration
        status          Checks Code Manager status

      #{colorize(:cyan, 'Description')}
        Runs remote code deployments with the Code Manager service.

      #{colorize(:cyan, 'Options')}
    HELP

    CODE_DEPLOY_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
        code deploy

      #{colorize(:cyan, 'Usage')}
        pupent code deploy [<environment> | --all] [options]

      #{colorize(:cyan, 'Description')}
        Run remote code deployment(s) using code manager.

      #{colorize(:cyan, 'Options')}
    HELP

    CODE_STATUS_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
        code status

      #{colorize(:cyan, 'Usage')}
        pupent code status [options]

      #{colorize(:cyan, 'Description')}
        Print the status of the code manager service

      #{colorize(:cyan, 'Options')}
    HELP

    CODE_DEPLOY_STATUS_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
        code deploy-status

      #{colorize(:cyan, 'Usage')}
        pupent code deploy-status [deploy ID] [options]

      #{colorize(:cyan, 'Description')}
        Print the status of code deployments

      #{colorize(:cyan, 'Options')}
    HELP

    ACCESS_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
        access

      #{colorize(:cyan, 'Usage')}
        pupent access [action] [options]

      #{colorize(:cyan, 'Actions')}
        login                Login and generate a token
        show                 Print the locally saved token
        delete-token-file    Delete the locally saved token

      #{colorize(:cyan, 'Description')}
        pupent access provides commands for fetching a new token from Puppet Enterprise

      #{colorize(:cyan, 'Options')}
    HELP

    ACCESS_LOGIN_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
        access login

      #{colorize(:cyan, 'Usage')}
        pupent access login [options]

      #{colorize(:cyan, 'Description')}
        login to Puppet Enterprise and generate an RBAC token usable for further authentication

      #{colorize(:cyan, 'Options')}
    HELP

    ACCESS_SHOW_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
        access show

      #{colorize(:cyan, 'Usage')}
        pupent access show [options]

      #{colorize(:cyan, 'Description')}
        Print the locally saved Puppet Enterprise RBAC token to stdout

      #{colorize(:cyan, 'Options')}
    HELP

    ACCESS_DELETE_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
        access delete-token-file

      #{colorize(:cyan, 'Usage')}
        pupent access delete-token-file [options]

      #{colorize(:cyan, 'Description')}
        Delete the locally saved Puppet Enterprise RBAC token

      #{colorize(:cyan, 'Options')}
    HELP

    # rubocop:disable Layout/LineLength
    def self.all_globals(parser)
      parser.on(
        "--log-level LEVEL",
        "Logging level to display"
      )
      parser.on(
        "--pe-host FQDN",
        "Fully Qualified Domain Name of the PE primary"
      )
      parser.on(
        "--ca-cert CERT",
        "Location on the local system of the PE Primary's CA Certificate. (default \"/etc/puppetlabs/puppet/ssl/certs/ca.pem\")"
      )
      parser.on(
        "-c",
        "--config-file FILE",
        "Location on the local system of the config file for PupEnt"
      )
      parser.on(
        "-s",
        "--save-config",
        "Save token-file, ca-cert, and pe-host/service-url configuration passed as CLI args to the local config file"
      )
      parser.on_tail("-h", "--help", "Prints help and usage information")
      parser.on_tail("-V", "--version", "Show version")
    end

    def self.access_globals(parser)
      parser.on("--service-url FULL_URL", "FQDN, port, and API prefix of server where token issuing service/server can be contacted")
    end

    def self.access_login(parser)
      parser.on("--lifetime LIFETIME", "Lifetime of the token")
      parser.on("-t", "--token-file FILE", "Location on the local system of the token file. (default #{ENV['HOME']}/.pupent/token")
    end

    def self.code_globals(parser)
      parser.on("--service-url FULL_URL", "FQDN, port, and API prefix of server where code manager can be contacted")
    end

    def self.code_deploy(parser)
      parser.on("--all", "Run deployments for all environments")
      parser.on("--wait", "Wait for the server to finish deploying")
    end
    # rubocop:enable Layout/LineLength

    def self.parse(argv)
      # Do not set any default values here: merging the values
      # provided on the CLI with default values happens in the
      # CLI class, and default values are defined in the Config
      # class.
      args = {}
      parser = OptionParser.new do |prsr|
        all_globals(prsr)
        prsr.banner = ALL_HELP
      end

      # Use a second OptionParser to parse all possible
      # options, allowing us to find the command and
      # action
      remaining = OptionParser.new do |prsr|
        all_globals(prsr)
        access_globals(prsr)
        access_login(prsr)
        code_globals(prsr)
        code_deploy(prsr)
      end.permute(argv)
      command = remaining.shift
      action = remaining.shift
      object = remaining.shift

      case command
      when "access"
        parser.banner = ACCESS_HELP
        access_globals(parser)
        case action
        when "login"
          parser.banner = ACCESS_LOGIN_HELP
          access_login(parser)
        when "show"
          parser.banner = ACCESS_SHOW_HELP
          # No options to add
        when "delete-token-file"
          parser.banner = ACCESS_DELETE_HELP
          # No options to add
        else
          args[:help] = true
        end
      when 'code'
        parser.banner = CODE_HELP
        code_globals(parser)
        case action
        when 'deploy'
          parser.banner = CODE_DEPLOY_HELP
          code_deploy(parser)
        when 'status'
          parser.banner = CODE_STATUS_HELP
          # No options to add
        when 'deploy-status'
          parser.banner = CODE_DEPLOY_STATUS_HELP
          # No options to add
        else
          args[:help] = true
        end
      else
        args[:help] = true
      end

      parser.parse(argv, into: args)
      # All keys should become downcased symbols using underscores everywhere.
      args.transform_keys! { |key| key.to_s.downcase.gsub("-", "_").to_sym }
      # If the user asked for help or version, just bail here.
      if args[:version]
        $stdout.puts Bolt::VERSION
        raise PupEnt::CLIExit
      # Check for :help second, since --version probably doesn't include a
      # command and :help might also be true
      elsif args[:help]
        $stderr.puts(parser.help)
        raise PupEnt::CLIExit
      end
      [command, action, object, args]
    end
  end
end
