# frozen_string_literal: true

require 'bolt_spec/integration'
require 'bolt_spec/project'

describe Bolt::Application do
  include BoltSpec::Integration
  include BoltSpec::Project

  # Execute all tests in the context of a temporary project. This allows us to
  # write specific config and inventory for a test and automatically clean up
  # any files that Bolt may write.
  around(:each) do |example|
    with_project(config: config, inventory: inventory) do |project|
      @project = project
      example.run
    end
  end

  # Suppress output written to stdout and stderr.
  before(:each) do
    allow($stdin).to receive(:puts)
    allow($stderr).to receive(:puts)
  end

  let(:config)    { {} }
  let(:inventory) { {} }
  let(:project)   { @project }

  describe 'guide' do
    it 'lists topics' do
      output = run_cli_json(%w[guide], project: project)
      expect(output.keys).to match_array(%w[topics])
    end

    it 'prints a guide' do
      output = run_cli_json(%w[guide inventory], project: project)
      expect(output.keys).to match_array(%w[documentation guide topic])
      expect(output['topic']).to eq('inventory')
      expect(output['guide']).to match(/The inventory describes the targets/m)
    end

    it 'errors with an unknown topic' do
      expect { run_cli_json(%w[guide foo], project: project) }.to raise_error(
        Bolt::Error,
        /Unknown topic 'foo'. For a list of available topics, run 'bolt guide'./
      )
    end
  end
end
