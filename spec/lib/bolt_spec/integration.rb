# frozen_string_literal: true

require 'bolt/cli'
require 'bolt_spec/puppetdb'

module BoltSpec
  module Integration
    include BoltSpec::PuppetDB

    def run_cli(arguments, rescue_exec: false, outputter: Bolt::Outputter::JSON)
      cli = Bolt::CLI.new(arguments)

      # prevent tests from reading users config
      allow(Bolt::Boltdir).to receive(:find_boltdir).and_return(Bolt::Boltdir.new(Dir.mktmpdir))
      allow(cli).to receive(:puppetdb_client).and_return(pdb_client)
      allow(cli).to receive(:analytics).and_return(Bolt::Analytics::NoopClient.new)

      output =  StringIO.new
      outputter = outputter.new(false, false, false, output)
      allow(cli).to receive(:outputter).and_return(outputter)
      allow(Bolt::Logger).to receive(:configure)

      if rescue_exec
        begin
          opts = cli.parse
          cli.execute(opts)
        # rubocop:disable Lint/SuppressedException
        rescue Bolt::Error
        end
        # rubocop:enable Lint/SuppressedException
      else
        opts = cli.parse
        cli.execute(opts)
      end
      output.string
    end

    def run_cli_json(arguments, **opts)
      output = run_cli(arguments + ['--format', 'json'], opts)

      begin
        result = JSON.parse(output, quirks_mode: true)
      rescue JSON::ParserError
        output = output.string unless output.is_a?(String)
        expect(output).to eq("Output should be JSON")
      end
      result
    end

    def run_nodes(arguments)
      result = run_cli_json(arguments)
      if result['_error'] || result['items'].any? { |r| r['status'] != 'success' }
        expect(result).to eq("Should have succeed on node" => true)
      end
      result['items'].map { |r| r['value'] }
    end

    def run_one_node(arguments)
      run_nodes(arguments).first
    end

    def run_failed_nodes(arguments)
      result = run_cli_json(arguments)
      expect(result['_error'] || result['items'].all? { |r| r['status'] != 'success' })
      result['items'].map { |r| r['value'] }
    end

    def run_failed_node(arguments)
      run_failed_nodes(arguments).first
    end
  end
end
