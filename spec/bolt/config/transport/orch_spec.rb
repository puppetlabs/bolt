# frozen_string_literal: true

require 'spec_helper'
require 'bolt/config/transport/orch'
require 'shared_examples/transport_config'

describe Bolt::Config::Transport::Orch do
  let(:transport) { Bolt::Config::Transport::Orch }
  let(:data) { { 'host' => 'example.com' } }
  let(:merge_data) { { 'service-url' => 'api.example.com' } }

  include_examples 'transport config'
  include_examples 'filters options'

  context 'using plugins' do
    let(:plugin_data)   { { 'host' => { '_plugin' => 'foo' } } }
    let(:resolved_data) { { 'host' => 'foo' } }

    include_examples 'plugins'
  end

  context 'validating' do
    %w[cacert host service-url task-environment token-file].each do |opt|
      it "#{opt} errors with wrong type" do
        data[opt] = 100
        expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
      end
    end

    %w[job-poll-interval job-poll-timeout].each do |opt|
      it "#{opt} errors with wrong type" do
        data[opt] = '100'
        expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
      end
    end

    context 'cacert' do
      it 'expands path relative to project' do
        allow(Bolt::Util).to receive(:validate_file).and_return(true)
        data['cacert'] = 'path/to/cacert'
        config = transport.new(data, project)
        expect(config['cacert']).to eq(File.expand_path('path/to/cacert', project))
      end
    end

    context 'token-file' do
      it 'expands path relative to project' do
        allow(Bolt::Util).to receive(:validate_file).and_return(true)
        data['token-file'] = 'path/to/token'
        config = transport.new(data, project)
        expect(config['token-file']).to eq(File.expand_path('path/to/token', project))
      end
    end
  end
end
