# frozen_string_literal: true

require 'spec_helper'
require 'bolt/config/transport/local'
require 'shared_examples/transport_config'

describe Bolt::Config::Local do
  let(:transport) { Bolt::Config::Local }
  let(:data) { { 'run-as' => 'root' } }
  let(:merge_data) { { 'tmpdir' => '/path/to/tmpdir' } }

  include_examples 'transport config'
  include_examples 'filters options'

  context 'using plugins' do
    let(:plugin_data) { { 'run-as' => { '_plugin' => 'foo' } } }

    include_examples 'plugins'
  end

  context 'validating' do
    include_examples 'interpreters'
    include_examples 'sudoable'

    %w[run-as sudo-executable sudo-password tmpdir].each do |opt|
      it "#{opt} errors with wrong type" do
        data[opt] = 100
        expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
      end
    end
  end
end
