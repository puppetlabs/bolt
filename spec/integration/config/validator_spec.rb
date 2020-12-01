# frozen_string_literal: true

require 'bolt_spec/integration'
require 'bolt_spec/project'

describe 'validating config' do
  include BoltSpec::Integration
  include BoltSpec::Project

  around(:each) do |example|
    with_project do
      example.run
    end
  end

  let(:command) { %w[inventory show --targets all] }

  context 'with valid config' do
    let(:project_config) do
      {
        'apply-settings' => {
          'show_diff' => true
        },
        'color' => false,
        'compile-concurrency' => 2,
        'format' => 'json',
        'log' => {
          'warn.log' => {
            'level' => 'warn',
            'append' => true
          },
          'bolt-debug.log' => 'disable'
        },
        'modulepath' => %w[
          modules
          site-modules
        ],
        'plans' => [
          'myproject::deploy'
        ],
        'puppetdb' => {
          'cacert' => '/path/to/cacert',
          'connect-timeout' => 20,
          'server_urls' => [
            'https://example.com'
          ]
        },
        'tasks' => [
          'myproject::install_server'
        ]
      }
    end

    it 'does not error' do
      expect { run_cli(command, project: project) }.not_to raise_error
    end
  end

  context 'with invalid config' do
    let(:project_config) do
      {
        'apply-settings' => {
          'show_diff' => 'yes'
        },
        'color' => 100,
        'compile-concurrency' => 0,
        'format' => 'invisible',
        'log' => {
          'warn.log' => {
            'level' => 'everything',
            'append' => 'no'
          },
          'bolt-debug.log' => 'disabled'
        },
        'modulepath' => {
          '_plugin' => 'yaml',
          'filepath' => '/path/to/modulepath.yaml'
        },
        'plans' => [
          'myproject::deploy',
          nil
        ],
        'puppetdb' => {
          'cacert' => [
            '/path/to/cacert'
          ],
          'connect-timeout' => 0,
          'server_urls' => 'https://example.com'
        },
        'tasks' => {
          'myproject' => ['install_server']
        }
      }
    end

    it 'raises an error listing all errors in config' do
      expect { run_cli(command, project: project) }.to raise_error do |error|
        expect(error.kind).to eq('bolt/validation-error')

        expect(error.message.lines).to include(
          /Value at 'apply-settings.show_diff' must be of type Boolean/,
          /Value at 'color' must be of type Boolean/,
          /Value at 'compile-concurrency' must be a minimum of 1/,
          /Value at 'format' must be one of human, json, rainbow/,
          /Value at 'log.warn.log.level' must be one of/,
          /Value at 'log.warn.log.append' must be of type Boolean/,
          /Value at 'log.bolt-debug.log' must be disable or must be of type Hash/,
          /Value at 'modulepath' is a plugin reference, which is unsupported at this location/,
          /Value at 'puppetdb.cacert' must be of type String/,
          /Value at 'puppetdb.server_urls' must be of type Array/,
          /Value at 'tasks' must be of type Array/
        )
      end
    end
  end

  context 'with unknown config options' do
    let(:project_config) do
      {
        'unknown' => 'unknown',
        'puppetfile' => {
          'unknown' => 'unknown'
        }
      }
    end

    it 'warns about unknown options' do
      run_cli(command, project: project)

      expect(@log_output.readlines).to include(
        /WARN.*Unknown option 'unknown' at.*bolt-project.yaml/,
        /WARN.*Unknown option 'unknown' at 'puppetfile' at.*bolt-project.yaml/
      )
    end
  end
end
