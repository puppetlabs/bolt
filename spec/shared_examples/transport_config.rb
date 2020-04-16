# frozen_string_literal: true

require 'bolt/util'
require 'bolt/plugin'
require 'bolt/config/transport/base'

shared_examples 'transport config' do
  let(:boltdir) { File.expand_path(__dir__) }

  it 'defines OPTIONS' do
    expect(defined? transport::OPTIONS).to be
  end

  it 'defines DEFAULTS' do
    expect(defined? transport::DEFAULTS).to be
  end

  it 'sets default options' do
    expect(transport.new.to_h).to eq(transport::DEFAULTS)
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

  it 'errors when merging something other than a Hash or config' do
    config = transport.new
    expect { config.merge(['data']) }.to raise_error(Bolt::ValidationError)
  end
end

shared_examples 'filters options' do
  it 'filters invalid options' do
    data['foo'] = 'bar'
    expect(transport.new(data).to_h).not_to include('foo' => 'bar')
  end
end

shared_examples 'plugins' do
  let(:plugins) { Bolt::Plugin.setup(Bolt::Config.default, nil, nil, Bolt::Analytics::NoopClient.new) }

  it 'accepts plugin references' do
    expect { transport.new(plugin_data) }.not_to raise_error
  end

  it 'does not validate with plugin references' do
    expect_any_instance_of(transport).not_to receive(:validate)
    transport.new(plugin_data)
  end

  it 'resolves and validates plugin data' do
    allow(plugins).to receive(:resolve_references).and_return(resolved_data)
    config = transport.new(plugin_data)

    expect(config).to receive(:validate)
    config.resolve(plugins)

    expect(config.to_h).to include(resolved_data)
  end

  it 'errors when accessing data before resolving' do
    config = transport.new(plugin_data)

    expect { config.to_h }.to raise_error(Bolt::Error)
    expect { config['foo'] }.to raise_error(Bolt::Error)
    expect { config.dig('foo') }.to raise_error(Bolt::Error)
    expect { config.fetch('foo') }.to raise_error(Bolt::Error)
    expect { config.include?('foo') }.to raise_error(Bolt::Error)
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
