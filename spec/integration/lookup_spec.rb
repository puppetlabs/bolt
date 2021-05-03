# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/env_var'
require 'bolt_spec/files'
require 'bolt_spec/integration'

describe 'lookup' do
  include BoltSpec::EnvVar
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:project)      { fixtures_path('hiera') }
  let(:hiera_config) { File.join(project, 'hiera.yaml') }
  let(:plan)         { 'test::lookup' }

  after(:each) do
    Puppet.settings.send(:clear_everything_for_tests)
  end

  context 'plan function' do
    let(:cli_command) {
      %W[plan run #{plan} --project #{project} --hiera-config #{hiera_config}]
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
      let(:hiera_config) { File.join(project, 'hiera_interpolations.yaml') }

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
      around(:each) do |example|
        env_vars = {
          'BOLT_PKCS7_PUBLIC_KEY'  => File.read(File.expand_path('../keys/public_key.pkcs7.pem', project)),
          'BOLT_PKCS7_PRIVATE_KEY' => File.read(File.expand_path('../keys/private_key.pkcs7.pem', project))
        }

        with_env_vars(env_vars) do
          example.run
        end
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
      let(:hiera_config) { File.join(project, 'hiera_missing_backend.yaml') }

      it 'returns an error' do
        result = run_cli_json(cli_command + %w[key=test::backends])
        expect(result).to include(
          'kind' => 'bolt/pal-error',
          'msg'  => /Unable to find 'data_hash' function named 'missing_backend'/
        )
      end
    end

    context 'with plan_hiera' do
      let(:hiera_config) { File.join(project, 'plan_hiera.yaml') }
      let(:plan)         { 'test::plan_lookup' }
      let(:uri)          { 'localhost' }

      it 'uses plan_hierarchy outside apply block, and hierarchy in apply block' do
        result = run_cli_json(cli_command + %W[-t #{uri}])
        expect(result['outside_apply']).to eq('goes the weasel')
        expect(result['in_apply'].keys).to include('Notify[tarts]')
      end
    end

    context 'with invalid plan_hierarchy' do
      let(:hiera_config) { File.join(project, 'plan_hiera_interpolations.yaml') }
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

  context 'command', ssh: true do
    include BoltSpec::Conn

    let(:opts)   { %W[--project #{project} --hiera-config #{hiera_config} -t #{target}] }
    let(:target) { 'puppet_7_node' }

    around(:each) do |example|
      inventory = docker_inventory.merge('vars' => { 'lookup' => 'var' }).to_json

      env_vars = {
        'BOLT_INVENTORY'         => inventory,
        'BOLT_PKCS7_PUBLIC_KEY'  => File.read(File.expand_path('../keys/public_key.pkcs7.pem', project)),
        'BOLT_PKCS7_PRIVATE_KEY' => File.read(File.expand_path('../keys/private_key.pkcs7.pem', project))
      }

      with_env_vars(env_vars) do
        example.run
      end
    end

    it 'looks up a value' do
      result, = run_cli_json(%w[lookup environment] + opts)
      expect(result).to include(
        'object' => 'environment',
        'value'  => { 'value' => 'environment data/common.yaml' }
      )
    end

    context 'with interpolations' do
      let(:hiera_config) { File.join(project, 'hiera_interpolations.yaml') }

      it 'looks up a value with facts' do
        result, = run_cli_json(%w[lookup os] + opts)
        expect(result).to include(
          'object' => 'os',
          'value'  => { 'value' => 'os data/os/Ubuntu.yaml' }
        )
      end

      it 'looks up a value with vars' do
        result, = run_cli_json(%w[lookup var] + opts)
        expect(result).to include(
          'object' => 'var',
          'value'  => { 'value' => 'var data/var.yaml' }
        )
      end

      it 'looks up a value with a trusted fact' do
        result, = run_cli_json(%w[lookup certname] + opts)
        expect(result).to include(
          'object' => 'certname',
          'value'  => { 'value' => 'certname data/puppet_7_node.yaml' }
        )
      end
    end

    it 'looks up a value in the module hierarchy' do
      result, = run_cli_json(%w[lookup test::module] + opts)
      expect(result).to include(
        'object' => 'test::module',
        'value'  => { 'value' => 'test::module modules/test/data/common.yaml' }
      )
    end

    it 'errors with a missing key' do
      result, = run_cli_json(%w[lookup fizzbuzz] + opts)

      expect(result.dig('value', '_error', 'msg')).to eq(
        "Function lookup() did not find a value for the name 'fizzbuzz'"
      )
    end

    it 'looks up a value with a built-in backend' do
      result, = run_cli_json(%w[lookup test::secret] + opts)
      expect(result).to include(
        'object' => 'test::secret',
        'value'  => { 'value' => 'test::secret data/secret.eyaml' }
      )
    end

    it 'looks up a value with a custom backend' do
      result, = run_cli_json(%w[lookup test::custom] + opts)
      expect(result).to include(
        'object' => 'test::custom',
        'value'  => { 'value' => 'test::custom data/custom.txt' }
      )
    end

    context 'with a missing backend' do
      let(:hiera_config) { File.join(project, 'hiera_missing_backend.yaml') }

      it 'returns an error' do
        result, = run_cli_json(%w[lookup test::backends] + opts)
        expect(result.dig('value', '_error', 'msg')).to match(
          /Unable to find 'data_hash' function named 'missing_backend'/
        )
      end
    end

    it 'looks up the same value as a plan lookup' do
      plan_result     = run_cli_json(%W[plan run #{plan} key=environment] + opts)
      command_result, = run_cli_json(%w[lookup environment] + opts)

      expect(command_result.dig('value', 'value')).to eq(plan_result)
    end
  end
end
