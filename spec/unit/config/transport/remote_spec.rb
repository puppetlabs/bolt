# frozen_string_literal: true

require 'spec_helper'
require 'bolt/config/transport/remote'
require 'shared_examples/transport_config'

describe Bolt::Config::Transport::Remote do
  let(:transport) { Bolt::Config::Transport::Remote }
  let(:data) { { 'run-on' => 'proxy1.com' } }
  let(:merge_data) { { 'tmpdir' => 'proxy2.com' } }

  include_examples 'transport config'

  context 'using plugins' do
    let(:plugin_data)   { { 'run-on' => { '_plugin' => 'foo' } } }
    let(:resolved_data) { { 'run-on' => 'foo' } }

    include_examples 'plugins'
  end

  context 'validating' do
    it 'run-on errors with wrong type' do
      data['run-on'] = 100
      expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
    end
  end
end
