# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/integration'

describe "lookup() in plans" do
  include BoltSpec::Files
  include BoltSpec::Integration

  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  let(:boltdir)      { fixtures_path('hiera') }
  let(:hiera_config) { File.join(boltdir, 'hiera.yaml') }
  let(:plan)         { 'test::lookup' }

  let(:cli_command) {
    %W[plan run #{plan} --project #{boltdir} --hiera-config #{hiera_config}]
  }

  it 'returns a value' do
    result = run_cli_json(cli_command + %w[key=environment])
    expect(result).to eq('environment data/common.yaml')
  end

  it 'accepts a default value' do
    options = { 'default_value' => 'default' }.to_json
    result  = run_cli_json(cli_command + %W[key=foo::bar::baz options=#{options}])
    expect(result).to eq('default')
  end

  it 'accepts a default values hash' do
    options = { 'default_values_hash' => { 'foo::bar::baz' => 'default' } }.to_json
    result  = run_cli_json(cli_command + %W[key=foo::bar::baz options=#{options}])
    expect(result).to eq('default')
  end

  it 'searches the module hierarchy' do
    result = run_cli_json(cli_command + %w[key=test::module])
    expect(result).to eq('test::module modules/test/data/common.yaml')
  end

  it 'does not search the module hierarchy in a different namespace' do
    result = run_cli_json(cli_command + %w[key=foo::namespace])
    expect(result).to include(
      'kind' => 'bolt/pal-error',
      'msg'  => /Function lookup\(\) did not find a value for the name 'foo::namespace'/
    )
  end

  it 'does not search for global keys in the module hierarchy' do
    result = run_cli_json(cli_command + %w[key=global])
    expect(result).to include(
      'kind' => 'bolt/pal-error',
      'msg'  => /Function lookup\(\) did not find a value for the name 'global'/
    )
  end

  it 'merges values' do
    options = { 'merge' => 'deep' }.to_json
    result  = run_cli_json(cli_command + %W[key=test::merge options=#{options}])
    expect(result).to match(
      'bolt'   => { 'key1' => 'value1', 'key2' => 'value1' },
      'puppet' => { 'key1' => 'value1' }
    )
  end

  context 'with a lambda' do
    let(:plan) { 'test::lookup_lambda' }

    it 'returns a value from the lambda' do
      result = run_cli_json(cli_command + %w[key=foo::bar::baz])
      expect(result).to eq('foo bar baz lambda')
    end

    it 'returns a value from the lambda over the default value' do
      options = { 'default_value' => 'default' }.to_json
      result = run_cli_json(cli_command + %W[key=foo::bar::baz options=#{options}])
      expect(result).to eq('foo bar baz lambda')
    end

    it 'returns a value from the default values hash over the lambda' do
      options = { 'default_values_hash' => { 'foo::bar::baz' => 'default values hash' } }.to_json
      result  = run_cli_json(cli_command + %W[key=foo::bar::baz options=#{options}])
      expect(result).to eq('default values hash')
    end
  end

  context 'with interpolations' do
    let(:hiera_config) { File.join(boltdir, 'hiera_interpolations.yaml') }

    it 'returns an error' do
      result = run_cli_json(cli_command + %w[key=test::interpolations])
      expect(result).to include(
        'kind' => 'bolt/pal-error',
        'msg'  => /Interpolations are not supported in lookups/
      )
    end
  end

  context 'with a builtin backend' do
    # Load pkcs7 keys as environment variables
    before(:each) do
      ENV['BOLT_PKCS7_PUBLIC_KEY']  = File.read(File.expand_path('../keys/public_key.pkcs7.pem', boltdir))
      ENV['BOLT_PKCS7_PRIVATE_KEY'] = File.read(File.expand_path('../keys/private_key.pkcs7.pem', boltdir))
    end

    after(:each) do
      ENV.delete('BOLT_PKCS7_PUBLIC_KEY')
      ENV.delete('BOLT_PKCS7_PRIVATE_KEY')
    end

    it 'returns a value' do
      result = run_cli_json(cli_command + %w[key=test::secret])
      expect(result).to eq('test::secret data/secret.eyaml')
    end
  end

  context 'with a custom backend' do
    it 'returns a value' do
      result = run_cli_json(cli_command + %w[key=test::custom])
      expect(result).to eq('test::custom data/custom.txt')
    end
  end

  context 'with a missing backend' do
    let(:hiera_config) { File.join(boltdir, 'hiera_missing_backend.yaml') }

    it 'returns an error' do
      result = run_cli_json(cli_command + %w[key=test::backends])
      expect(result).to include(
        'kind' => 'bolt/pal-error',
        'msg'  => /Unable to find 'data_hash' function named 'missing_backend'/
      )
    end
  end

  context 'with plan_hiera' do
    let(:hiera_config) { File.join(boltdir, 'plan_hiera.yaml') }
    let(:plan)         { 'test::plan_lookup' }
    let(:uri)          { 'localhost' }

    it 'uses plan_hierarchy outside apply block, and hierarchy in apply block' do
      result = run_cli_json(cli_command + %W[-t #{uri}])
      expect(result['outside_apply']).to eq('goes the weasel')
      expect(result['in_apply'].keys).to include('Notify[tarts]')
    end
  end

  context 'with invalid plan_hierarchy' do
    let(:hiera_config) { File.join(boltdir, 'plan_hiera_interpolations.yaml') }
    let(:plan)         { 'test::plan_lookup' }
    let(:uri)          { 'localhost' }

    it 'raises a validation error' do
      result = run_cli_json(cli_command + %W[-t #{uri}])
      expect(result).to include(
        'kind' => 'bolt/pal-error',
        'msg'  => /Interpolations are not supported in lookups/
      )
    end
  end
end
