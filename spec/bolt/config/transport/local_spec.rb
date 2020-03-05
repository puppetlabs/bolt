# frozen_string_literal: true

require 'spec_helper'
require 'bolt/config/transport/local'
require 'shared_examples/transport_config'

describe Bolt::Config::Transport::Local do
  let(:transport)   { Bolt::Config::Transport::Local }
  let(:data)        { { 'interpreters' => { 'rb' => '/path/to/ruby' } } }
  let(:merge_data)  { { 'interpreters' => { 'py' => '/path/to/python' } } }
  let(:plugin_data) { { 'tmpdir' => { '_plugin' => 'foo' } } }

  context 'on Windows' do
    before(:each) do
      allow(Bolt::Util).to receive(:windows?).and_return(true)
    end

    include_examples 'transport config'
    include_examples 'filters options'
    include_examples 'plugins'

    context 'validating' do
      include_examples 'interpreters'

      it 'tmpdir errors with wrong type' do
        data['tmpdir'] = ['/path/to/tmpdir']
        expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
      end
    end
  end

  context 'on *nix' do
    before(:each) do
      allow(Bolt::Util).to receive(:windows?).and_return(false)
    end

    include_examples 'transport config'
    include_examples 'filters options'
    include_examples 'plugins'

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
end
