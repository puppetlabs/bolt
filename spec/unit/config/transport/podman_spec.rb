# frozen_string_literal: true

require 'spec_helper'
require 'bolt/config/transport/podman'
require 'shared_examples/transport_config'

describe Bolt::Config::Transport::Podman do
  let(:transport) { Bolt::Config::Transport::Podman }
  let(:data) { { 'host' => 'example.com' } }
  let(:merge_data) { { 'tmpdir' => '/path/to/tmpdir' } }

  include_examples 'transport config'
  include_examples 'filters options'

  context 'using plugins' do
    let(:plugin_data)   { { 'host' => { '_plugin' => 'foo' } } }
    let(:resolved_data) { { 'host' => 'foo' } }

    include_examples 'plugins'
  end

  context 'validating' do
    include_examples 'interpreters'

    it 'tty errors with wrong type' do
      data['tty'] = 'true'
      expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
    end

    %w[host shell-command tmpdir].each do |opt|
      it "#{opt} errors with wrong type" do
        data[opt] = 100
        expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
      end
    end
  end
end
