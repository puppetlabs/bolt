module BoltSpec
  module Integration
    def run_cli(arguments)
      cli = Bolt::CLI.new(arguments)

      # prevent tests from reading users config
      allow(cli.config).to receive(:default_paths).and_return([File.join('.', 'path', 'does not exist')])
      output =  StringIO.new
      outputter = Bolt::Outputter::JSON.new(output)
      allow(cli).to receive(:outputter).and_return(outputter)

      opts = cli.parse
      cli.execute(opts)
      output.string
    end

    def run_one_node(arguments)
      output = run_cli(arguments)

      begin
        result = JSON.parse(output)
      rescue JSON::ParserError
        expect(output.string).to eq("Output should be JSON")
      end

      if result['_error'] ||
         (result['items'] && result['items'][0] && result['items'][0]['status'] != 'success')
        expect(result).to eq("Should have succeed on node" => true)
      end
      result['items'][0]['result']
    end
  end
end
