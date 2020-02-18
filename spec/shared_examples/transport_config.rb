# frozen_string_literal: true

require 'bolt/util'
require 'bolt/config/transport'

shared_examples 'transport config' do
  let(:boltdir) { File.expand_path(__dir__) }

  it 'defines OPTIONS' do
    expect(defined? transport::OPTIONS).to be
  end

  it 'defines DEFAULTS' do
    expect(defined? transport::DEFAULTS).to be
  end

  it 'sets default options' do
    expect(transport.new.config).to eq(transport::DEFAULTS)
  end

  it 'validates when initializing' do
    expect_any_instance_of(transport).to receive(:validate)
    transport.new
  end

  it 'initializes new config when merging' do
    config = transport.new
    expect(transport).to receive(:new)
    config.merge(merge_data)
  end

  it 'errors when setting config something other than a Hash' do
    config = transport.new
    expect { config.config = ['data'] }.to raise_error(Bolt::ValidationError)
  end

  it 'errors when merging something other than a Hash' do
    config = transport.new
    expect { config.merge(['data']) }.to raise_error(Bolt::ValidationError)
  end

  it 'allows for overriding config completely' do
    config = transport.new
    config.config = data
    expect(config.config).to eq(data)
  end
end

shared_examples 'filters options' do
  it 'filters invalid options' do
    data['foo'] = 'bar'
    expect(transport.new(data).config).not_to include('foo' => 'bar')
  end
end

shared_examples 'plugins' do
  it 'accepts plugin references' do
    expect { transport.new(plugin_data) }.not_to raise_error
  end
end

shared_examples 'interpreters' do
  it 'normalizes interpreters' do
    data['interpreters'] = { 'rb' => '/path/to/ruby' }
    expect(transport.new(data)['interpreters']).to include('.rb')
  end

  it 'interpreters errors with wrong type' do
    data['interpreters'] = ['rb']
    expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
  end
end

shared_examples 'sudoable' do
  context 'run-as-command' do
    it 'errors with wrong type' do
      data['run-as-command'] = 'whoami'
      expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
    end

    it 'errors with wrong array element type' do
      data['run-as-command'] = ['whoami', 3]
      expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
    end
  end
end
