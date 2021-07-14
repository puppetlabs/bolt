# frozen_string_literal: true

require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/project'

describe 'validating config' do
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::Project

  around(:each) do |example|
    with_project_directory(config: project_config, inventory: inventory) do |project_path|
      @project_path = project_path
      example.run
    end
  end

  before(:each) do
    allow($stderr).to receive(:puts)
    allow($stdout).to receive(:puts)
  end

  let(:command)        { %W[inventory show --targets all --project #{@project_path} --modulepath #{modulepath}] }
  let(:inventory)      { nil }
  let(:modulepath)     { fixtures_path('plugin_modules') }
  let(:project_config) { nil }

  context 'with plugin reference' do
    context 'at plugins' do
      let(:project_config) do
        {
          'plugins' => {
            '_plugin' => 'identity',
            'value' => 'foo'
          }
        }
      end

      it 'errors' do
        expect { run_cli(command) }.to raise_error(
          Bolt::ValidationError,
          /Value at 'plugins' is a plugin reference, which is unsupported at this location/
        )
      end
    end

    context 'at plugins.*' do
      let(:project_config) do
        {
          'plugins' => {
            'pkcs7' => {
              '_plugin' => 'identity',
              'value' => {
                'keysize' => 2048
              }
            }
          }
        }
      end

      it 'does not error' do
        expect { run_cli(command) }.not_to raise_error
      end
    end

    context 'at ssh.private-key.key-data' do
      let(:inventory) do
        {
          'config' => {
            'ssh' => {
              'private-key' => {
                'key-data' => {
                  '_plugin' => 'identity',
                  'value' => 'foo'
                }
              }
            }
          }
        }
      end

      it 'does not error' do
        expect { run_cli(command) }.not_to raise_error
      end
    end

    context 'at ssh.interpreters' do
      let(:inventory) do
        {
          'config' => {
            'ssh' => {
              'interpreters' => {
                '_plugin' => 'identity',
                'value' => {
                  '.rb' => '/opt/puppetlabs/puppet/bin/ruby'
                }
              }
            }
          }
        }
      end

      it 'does not error' do
        expect { run_cli(command) }.not_to raise_error
      end
    end

    context 'at ssh.interpreters.*' do
      let(:inventory) do
        {
          'config' => {
            'ssh' => {
              'interpreters' => {
                'rb' => {
                  '_plugin' => 'identity',
                  'value' => '/opt/puppetlabs/puppet/bin/ruby'
                }
              }
            }
          }
        }
      end

      it 'errors' do
        expect { run_cli(command) }.to raise_error(
          Bolt::ValidationError,
          /Value at 'config.ssh.interpreters.rb' is a plugin reference, which is unsupported at this location/
        )
      end
    end
  end

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
      expect { run_cli(command) }.not_to raise_error
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
      expect { run_cli(command) }.to raise_error do |error|
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

  context 'with valid inventory' do
    let(:inventory) do
      {
        'groups' => [
          {
            'name' => 'nix',
            'targets' => [
              'nix1-example.org',
              'nix2-example.org'
            ],
            'facts' => {
              'operatingsystem' => 'linux'
            },
            'features' => [
              'puppet-agent'
            ]
          },
          {
            'name' => 'windows',
            'targets' => [
              {
                'name' => 'win1',
                'uri' => 'win1-example.org'
              }
            ],
            'groups' => [
              {
                'name' => 'subgroup',
                'targets' => [
                  'win3-example.org',
                  'win4-example.org'
                ],
                'config' => {
                  'winrm' => {
                    'ssl' => false
                  }
                }
              }
            ]
          }
        ],
        'config' => {
          'transport' => 'ssh',
          'ssh' => {
            'host-key-check' => false
          },
          'remote' => {
            'port' => 1234,
            'token' => 5678
          },
          'winrm' => {
            'user' => 'Administrator',
            'password' => 'bolt'
          }
        }
      }
    end

    it 'does not error or raise warnings' do
      expect { run_cli(command) }.not_to raise_error
      expect(@log_output.readlines).not_to include(/Unknown option.*inventory/)
    end
  end

  context 'with invalid inventory' do
    let(:inventory) do
      {
        'groups' => [
          {
            'targets' => [
              'nix1-example.org',
              100
            ],
            'facts' => [
              'linux'
            ],
            'features' => {
              'puppet-agent' => true
            }
          },
          {
            'name' => 'windows',
            'targets' => [
              {
                'name' => 'win1',
                'uri' => 'win1-example.org',
                'transport' => 'winrm'
              }
            ],
            'groups' => {
              'name' => 'subgroup',
              'targets' => [
                'win3-example.org',
                'win4-example.org'
              ],
              'config' => {
                'winrm' => {
                  'ssl' => false
                }
              }
            }
          }
        ],
        'config' => {
          'transport' => 'foo',
          'ssh' => {
            'host-key-check' => 'no'
          },
          'winrm' => {
            'user' => 'Administrator',
            'password' => 100
          }
        }
      }
    end

    it 'raises an error listing all errors in inventory' do
      expect { run_cli(command) }.to raise_error do |error|
        expect(error.kind).to eq('bolt/validation-error')

        expect(error.message.lines).to include(
          /Value at 'groups.0' is missing required keys name/,
          /Value at 'groups.0.targets.1' must be of type String or Hash/,
          /Value at 'groups.0.facts' must be of type Hash/,
          /Value at 'groups.0.features' must be of type Array/,
          /Value at 'groups.1.groups' must be of type Array/,
          /Value at 'config.transport' must be one of/,
          /Value at 'config.ssh.host-key-check' must be of type Boolean/,
          /Value at 'config.winrm.password' must be of type String/
        )
      end
    end
  end

  context 'with unknown config options' do
    let(:project_config) do
      {
        'unknown' => 'unknown',
        'module-install' => {
          'unknown' => 'unknown'
        }
      }
    end

    it 'warns about unknown options' do
      run_cli(command)

      expect(@log_output.readlines).to include(
        /WARN.*Unknown option 'unknown' at.*bolt-project.yaml/,
        /WARN.*Unknown option 'unknown' at 'module-install' at.*bolt-project.yaml/
      )
    end
  end

  context 'with unknown inventory options' do
    let(:inventory) do
      {
        'groups' => [
          {
            'alias' => 'group',
            'name' => 'mygroup',
            'targets' => [
              {
                'uri' => 'target.example.com',
                'config' => {
                  'ssh' => {
                    'user' => 'bolt',
                    'ssl' => false,
                    'foo' => 'bar'
                  }
                }
              }
            ]
          }
        ]
      }
    end

    it 'warns about unknown options' do
      run_cli(command)

      expect(@log_output.readlines).to include(
        /WARN.*Unknown option 'alias' at 'groups.0' at.*inventory.yaml/,
        /WARN.*Unknown option 'ssl' at 'groups.0.targets.0.config.ssh' at.*inventory.yaml/,
        /WARN.*Unknown option 'foo' at 'groups.0.targets.0.config.ssh' at.*inventory.yaml/
      )
    end
  end

  context 'with plugins defined in puppetdb config' do
    let(:project_config) do
      {
        'puppetdb' => {
          'cacert' => {
            '_plugin' => 'env_var',
            'var' => 'BOLT_PUPPETDB_CACERT',
            'default' => '/path/to/cacert'
          },
          'cert' => {
            '_plugin' => 'env_var',
            'var' => 'BOLT_PUPPETDB_CERT',
            'default' => '/path/to/cert'
          },
          'connect-timeout' => {
            '_plugin' => 'env_var',
            'var' => 'BOLT_PUPPETDB_CONNECT_TIMEOUT',
            'default' => 20
          },
          'key' => {
            '_plugin' => 'env_var',
            'var' => 'BOLT_PUPPETDB_KEY',
            'default' => '/path/to/key'
          },
          'read-timeout' => {
            '_plugin' => 'env_var',
            'var' => 'BOLT_PUPPETDB_READ_TIMEOUT',
            'default' => 10
          },
          'server_urls' => {
            '_plugin' => 'env_var',
            'var' => 'BOLT_PUPPETDB_SERVER_URLS',
            'default' => [
              'https://example.com'
            ]
          },
          'token' => {
            '_plugin' => 'env_var',
            'var' => 'BOLT_PUPPETDB_TOKEN',
            'default' => '/path/to/token'
          }
        }
      }
    end

    it 'does not error' do
      expect { run_cli(command) }.not_to raise_error
    end
  end
end
