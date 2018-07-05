# frozen_string_literal: true

module BoltSpec
  module Integration
    def run_cli(arguments, rescue_exec: false, outputter: Bolt::Outputter::JSON)
      cli = Bolt::CLI.new(arguments)

      # prevent tests from reading users config
      allow(Bolt::Config).to receive(:legacy_conf).and_return(File.join('.', 'path', 'does not exist'))
      allow(Bolt::Boltdir).to receive(:find_boltdir).and_return(Bolt::Boltdir.new(Dir.mktmpdir))
      puppetdb_client = Bolt::PuppetDB::Client.new(URI.parse('https://puppetdb.example.com'), '/path/to/cacert')
      allow(cli).to receive(:puppetdb_client).and_return(puppetdb_client)
      output =  StringIO.new
      outputter = outputter.new(false, false, output)
      allow(cli).to receive(:outputter).and_return(outputter)
      allow(Bolt::Logger).to receive(:configure)

      opts = cli.parse

      if rescue_exec
        begin
          cli.execute(opts)
        # rubocop:disable HandleExceptions
        rescue Bolt::Error
        end
        # rubocop:enable HandleExceptions
      else
        cli.execute(opts)
      end
      output.string
    end

    def run_cli_json(arguments, **opts)
      output = run_cli(arguments, opts)

      begin
        result = JSON.parse(output, quirks_mode: true)
      rescue JSON::ParserError
        expect(output.string).to eq("Output should be JSON")
      end
      result
    end

    def run_one_node(arguments)
      result = run_cli_json(arguments)
      if result['_error'] || (result.dig('items', 0, 'status') != 'success')
        expect(result).to eq("Should have succeed on node" => true)
      end
      result['items'][0]['result']
    end

    def run_failed_node(arguments)
      result = run_cli_json(arguments)
      expect(result['_error'] || (result['items'] && result['items'][0] && result['items'][0]['status'] != 'success'))
      result['items'][0]['result']
    end
  end
end
