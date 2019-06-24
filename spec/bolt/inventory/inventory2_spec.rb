# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/config'
require 'bolt/inventory'
require 'bolt/plugin'

describe Bolt::Inventory::Inventory2 do
  include BoltSpec::Config

  def make_targets(names)
    names.map { |n| Bolt::Target.new(n) }
  end

  def get_target(inventory, name, alia = nil)
    targets = inventory.get_targets(alia || name)
    expect(targets.size).to eq(1)
    expect(targets[0].name).to eq(name)
    targets[0]
  end

  let(:plugins) { Bolt::Plugin.new(config) }
  let(:target_name) { "example.com" }
  let(:target_entry) { target_name }
  let(:targets) { [target_entry] }
  let(:groups) { [] }

  let(:data) do
    {
      'version' => 2,
      'targets' => targets,
      'groups' => groups
    }
  end

  let(:inventory) { Bolt::Inventory.create_version(data, config, plugins) }

  it 'creates simple inventory' do
    expect(inventory.class).to eq(Bolt::Inventory::Inventory2)
  end

  it 'gets a uri target from the inventory' do
    target = inventory.get_targets(target_name).first
    expect(target.uri).to eq(target_name)
  end

  it 'gets a uri target not in inventory' do
    target = inventory.get_targets("notininv.com").first
    expect(target.uri).to eq("notininv.com")
  end

  context 'with a uriless target' do
    let(:target_name) { 'uriless.com' }
    let(:target_entry) { { 'name' => target_name } }

    it 'does not have a uri' do
      target = inventory.get_targets(target_name).first
      expect(target.uri).to eq(nil)
    end
  end

  context 'with a uriless target referred to by name' do
    let(:target_name) { 'uriless.net' }
    let(:groups) do
      [{
        'name' => 'group1',
        'targets' => [target_name]
      },
       {
         'name' => 'group2',
         'targets' => [
           { 'name' => target_name }
         ]
       }]
    end

    it 'does not have a uri' do
      target = inventory.get_targets(target_name).first
      expect(target.uri).to eq(nil)
    end
  end

  context 'with a uriful target reffered to as an alias' do
    let(:target_name) { 'uriful.net' }
    let(:target_alias) { 'uriful' }
    let(:groups) do
      [{
        'name' => 'group1',
        'targets' => [{ 'uri' => target_name, 'alias' => [target_alias] }]
      },
       {
         'name' => 'group2',
         'targets' => [target_alias]
       }]
    end

    it 'has the uri' do
      target = inventory.get_targets(target_alias).first
      expect(target.uri).to eq(target_name)
    end
  end

  context 'legacy tests TODO: prune' do
    let(:data) {
      {
        'targets' => [
          'target1',
          { 'name' => 'target2' },
          { 'name' => 'target3',
            'config' => {
              'ssh' => {
                'user' => 'me'
              }
            } }
        ],
        'config' => {
          'ssh' => {
            'user' => 'you',
            'host-key-check' => false,
            'port' => '2222'
          }
        },
        'groups' => [
          { 'name' => 'group1',
            'targets' => [
              { 'uri' => 'target4',
                'config' => {
                  'ssh' => {
                    'user' => 'me'
                  }
                } },
              'target5',
              'target6',
              'target7'
            ],
            'config' => {
              'ssh' => {
                'host-key-check' => true
              }
            } },
          { 'name' => 'group2',
            'targets' => [
              { 'uri' => 'target6',
                'config' => {
                  'ssh' => { 'user' => 'someone' }
                } },
              'target7', 'ssh://target8'
            ],
            'groups' => [
              { 'name' => 'group3',
                'targets' => [
                  'target9'
                ] }
            ],
            'config' => {
              'ssh' => {
                'host-key-check' => false,
                'port' => '2223'
              }
            } }
        ]
      }
    }

    let(:ssh_target_option_defaults) {
      {
        'connect-timeout' => 10,
        'tty' => false,
        'host-key-check' => true
      }
    }

    describe :validate do
      it 'accepts empty inventory' do
        expect(Bolt::Inventory::Inventory2.new({}).validate).to be_nil
      end

      it 'accepts non-empty inventory' do
        expect(Bolt::Inventory::Inventory2.new(data).validate).to be_nil
      end

      it 'fails with unnamed groups' do
        data = { 'groups' => [{}] }
        expect {
          Bolt::Inventory::Inventory2.new(data).validate
        }.to raise_error(Bolt::Inventory::ValidationError, /Group does not have a name/)
      end

      it 'fails with unamed targets' do
        data = { 'targets' => [{ 'name' => '' }] }

        expect {
          Bolt::Inventory::Inventory2.new(data)
        }.to raise_error(Bolt::Inventory::ValidationError, /No name or uri for target/)
      end

      it 'fails with duplicate groups' do
        data = { 'groups' => [{ 'name' => 'group1' }, { 'name' => 'group1' }] }
        expect {
          Bolt::Inventory::Inventory2.new(data).validate
        }.to raise_error(Bolt::Inventory::ValidationError, /Tried to redefine group group1/)
      end
    end

    describe :collect_groups do
      it 'finds the all group with an empty inventory' do
        inventory = Bolt::Inventory::Inventory2.new({})
        expect(inventory.get_targets('all')).to eq([])
      end

      it 'finds the all group with a non-empty inventory' do
        inventory = Bolt::Inventory::Inventory2.new(data)
        targets = inventory.get_targets('all')
        expect(targets.size).to eq(9)
      end

      it 'finds targets in a subgroup' do
        inventory = Bolt::Inventory::Inventory2.new(data)
        targets = inventory.get_targets('group2')
        expect(targets).to eq(make_targets(%w[target6 target7 ssh://target8 target9]))
      end
    end

    context 'with an empty config' do
      let(:inventory) { Bolt::Inventory::Inventory2.new({}, config) }
      let(:target) { inventory.get_targets('notarget')[0] }

      it 'should accept an empty file' do
        expect(inventory).to be
      end

      it 'the all group should be empty' do
        expect(inventory.get_targets('all')).to eq([])
      end

      it 'should have the default protocol' do
        expect(target.protocol).to eq('ssh')
      end
    end

    context 'with config' do
      let(:inventory) {
        Bolt::Inventory::Inventory2.new({}, config('transport' => 'winrm',
                                                   'winrm' => {
                                                     'ssl' => false,
                                                     'ssl-verify' => false
                                                   }))
      }
      let(:target) { inventory.get_targets('notarget')[0] }

      it 'should have use protocol' do
        expect(target.protocol).to eq('winrm')
      end

      it 'should not use ssl' do
        expect(target.options['ssl']).to eq(false)
      end

      it 'should not use ssl-verify' do
        expect(target.options['ssl-verify']).to eq(false)
      end
    end

    describe 'get_targets' do
      context 'empty inventory' do
        let(:inventory) { Bolt::Inventory::Inventory2.new({}, config) }

        it 'should parse a single target URI' do
          name = 'notarget'
          expect(inventory.get_targets(name)).to eq(make_targets([name]))
        end

        it 'should parse an array of target URIs' do
          names = ['pcp://a', 'winrm://b', 'c']
          expect(inventory.get_targets(names)).to eq(make_targets(names))
        end

        it 'should parse a nested array of target URIs and Targets' do
          names = [['a'], Bolt::Target.new('b'), ['c', 'ssh://d']]
          expect(inventory.get_targets(names)).to eq(make_targets(['a', 'b', 'c', 'ssh://d']))
        end

        it 'should split a comma-separated list of target URIs' do
          ts = make_targets(['ssh://a', 'winrm://b:5000', 'u:p@c'])
          expect(inventory.get_targets('ssh://a, winrm://b:5000, u:p@c')).to eq(ts)
        end

        it 'should fail for unknown protocols' do
          expect {
            inventory.get_targets('z://foo')
          }.to raise_error(Bolt::UnknownTransportError, %r{Unknown transport z found for z://foo})
        end
      end

      context 'non-empty inventory' do
        let(:inventory) {
          inv = Bolt::Inventory::Inventory2.new(data)
          inv
        }

        it 'should parse an array of target URI and group name' do
          targets = inventory.get_targets(%w[a group1])
          expect(targets).to eq(make_targets(%w[a target4 target5 target6 target7]))
        end

        it 'should split a comma-separated list of target URI and group name' do
          matched_targets = %w[target4 target5 target6 target7 ssh://target8]
          targets = inventory.get_targets('group1,ssh://target8')
          expect(targets).to eq(make_targets(matched_targets))
        end

        it 'should match wildcard selectors' do
          targets = inventory.get_targets('target*')
          expect(targets.map(&:name).sort).to eq(%w[target1 target2 target3 target4 target5 target6 target7 target9])
        end

        it 'should fail if wildcard selector matches nothing' do
          expect {
            inventory.get_targets('*target')
          }.to raise_error(Bolt::Inventory::Inventory2::WildcardError,
                           /Found 0 targets matching wildcard pattern \*target/)
        end
      end

      context 'with data in the group' do
        let(:inventory) { Bolt::Inventory::Inventory2.new(data) }

        it 'should use value from lowest target definition' do
          expect(get_target(inventory, 'target4').user).to eq('me')
        end

        it 'should use values from the lowest group' do
          expect(get_target(inventory, 'target4').options).to include('host-key-check' => true)
        end

        it 'should include values from parents' do
          expect(get_target(inventory, 'target4').port).to eq('2222')
        end

        it 'should use values from the first group' do
          expect(get_target(inventory, 'target6').options).to include('host-key-check' => true)
        end

        it 'should prefer values from a target over an earlier group' do
          expect(get_target(inventory, 'target6').user).to eq('someone')
        end

        it 'should use values from matching groups' do
          expect(get_target(inventory, 'ssh://target8').port).to eq('2223')
        end

        it 'should only return config for exact matches' do
          expect(inventory.get_targets('target8')).to eq(make_targets(['target8']))
        end
      end

      context 'with targets at the top level' do
        let(:data) {
          {
            'name' => 'group1',
            'targets' => [
              'target1',
              { 'uri' => 'target2' },
              { 'uri' => 'target3',
                'config' => {
                  'ssh' => {
                    'data' => true,
                    'port' => '2224'
                  }
                } }
            ]
          }
        }
        let(:inventory) { Bolt::Inventory::Inventory2.new(data) }

        it 'should initialize' do
          expect(inventory).to be
        end

        it 'should return {} for a string target' do
          expect(get_target(inventory, 'target1').options).to include(ssh_target_option_defaults)
        end

        it 'should return {} for a hash target with no config' do
          expect(get_target(inventory, 'target2').options).to include(ssh_target_option_defaults)
        end

        it 'should return config for the target' do
          target = get_target(inventory, 'target3')
          expect(target.options).to eq(ssh_target_option_defaults.merge('port' => '2224',
                                                                        'name' => 'target3',
                                                                        "load-config" => true))
          expect(target.port).to eq('2224')
        end

        it 'should return the raw target for an unknown target' do
          expect(inventory.get_targets('target5')).to eq(make_targets(['target5']))
        end
      end

      context 'with simple data in the group' do
        let(:data) {
          {
            'targets' => [
              'target1',
              { 'name' => 'target2' },
              { 'name' => 'target3',
                'config' => {
                  'ssh' => {
                    'user' => 'me'
                  }
                } }
            ],
            'config' => {
              'ssh' => {
                'user' => 'you',
                'host-key-check' => false
              }
            }
          }
        }
        let(:inventory) { Bolt::Inventory::Inventory2.new(data) }

        it 'should return group config for string targets' do
          target = get_target(inventory, 'target1')
          expect(target.options).to include('host-key-check' => false)
          expect(target.user).to eq('you')
        end

        it 'should return group config for array targets' do
          target = get_target(inventory, 'target2')
          expect(target.options).to include('host-key-check' => false)
          expect(target.user).to eq('you')
        end

        it 'should merge config for from targets' do
          target = get_target(inventory, 'target3')
          expect(target.options).to include('host-key-check' => false)
          expect(target.user).to eq('me')
        end
      end

      context 'with config errors in data' do
        let(:inventory) { Bolt::Inventory::Inventory2.new(data) }

        context 'host-key-check' do
          let(:data) {
            {
              'targets' => ['target'],
              'config' => { 'ssh' => { 'host-key-check' => 'false' } }
            }
          }

          it 'fails validation' do
            expect { inventory.get_targets('target') }.to raise_error(Bolt::ValidationError)
          end
        end

        context 'connect-timeout' do
          let(:data) {
            {
              'targets' => ['target'],
              'config' => { 'winrm' => { 'connect-timeout' => '10' } }
            }
          }

          it 'fails validation' do
            expect { inventory.get_targets('target') }.to raise_error(Bolt::ValidationError)
          end
        end

        context 'ssl' do
          let(:data) {
            {
              'targets' => ['target'],
              'config' => { 'winrm' => { 'ssl' => 'true' } }
            }
          }

          it 'fails validation' do
            expect { inventory.get_targets('target') }.to raise_error(Bolt::ValidationError)
          end
        end

        context 'ssl-verify' do
          let(:data) {
            {
              'targets' => ['target'],
              'config' => { 'winrm' => { 'ssl-verify' => 'true' } }
            }
          }

          it 'fails validation' do
            expect { inventory.get_targets('target') }.to raise_error(Bolt::ValidationError)
          end
        end

        context 'transport' do
          let(:data) {
            {
              'targets' => ['target'],
              'config' => { 'transport' => 'z' }
            }
          }

          it 'fails validation' do
            expect { inventory.get_targets('target') }.to raise_error(Bolt::UnknownTransportError)
          end
        end
      end

      context 'with aliases' do
        let(:data) {
          {
            'targets' => [
              'target1',
              { 'name' => 'target2', 'alias' => 'alias1' },
              { 'name' => 'target3',
                'alias' => %w[alias2 alias3],
                'config' => {
                  'ssh' => {
                    'user' => 'me'
                  }
                } }
            ],
            'groups' => [
              { 'name' => 'group1', 'targets' => %w[target1 alias1 target4] }
            ],
            'config' => {
              'ssh' => {
                'user' => 'you',
                'host-key-check' => false
              }
            }
          }
        }
        let(:inventory) { Bolt::Inventory::Inventory2.new(data) }

        it 'should return group config for an alias' do
          target = get_target(inventory, 'target2', 'alias1')
          expect(target.options).to include('host-key-check' => false)
          expect(target.user).to eq('you')
        end

        it 'should merge config from targets' do
          target = get_target(inventory, 'target3', 'alias3')
          expect(target.options).to include('host-key-check' => false)
          expect(target.user).to eq('me')
        end

        it 'should return multiple targets' do
          targets = inventory.get_targets(%w[target1 alias1 alias2])
          expect(targets.count).to eq(3)
          expect(targets.map(&:name)).to eq(%w[target1 target2 target3])
        end

        it 'should resolve target labels' do
          targets = inventory.get_targets('group1')
          expect(targets.count).to eq(3)
          expect(targets.map(&:name)).to eq(%w[target1 target2 target4])
        end
      end

      context 'with all options in the config' do
        def common_data(transport)
          {
            'user' => 'me' + transport,
            'password' => 'you' + transport,
            'port' => '12345' + transport,
            'private-key' => 'anything',
            'ssl' => false,
            'ssl-verify' => false,
            'host-key-check' => false,
            'connect-timeout' => transport.size,
            'tmpdir' => '/' + transport,
            'run-as' => 'root',
            'tty' => true,
            'sudo-password' => 'nothing',
            'extensions' => '.py',
            'service-url' => 'https://master',
            'cacert' => transport + '.pem',
            'token-file' => 'token',
            'task-environment' => 'prod'
          }
        end

        let(:data) {
          {
            'targets' => ['ssh://target', 'winrm://target', 'pcp://target', 'target'],
            'config' => {
              'transport' => 'winrm',
              'modulepath' => 'nonsense',
              'ssh' => common_data('ssh'),
              'winrm' => common_data('winrm'),
              'pcp' => common_data('pcp')
            }
          }
        }
        let(:conf) { Bolt::Config.default }
        let(:inventory) { Bolt::Inventory::Inventory2.new(data, conf) }

        it 'should not modify existing config' do
          get_target(inventory, 'ssh://target')
          expect(conf.transport).to eq('ssh')
          expect(conf.transports[:ssh]['host-key-check']).to be true
          expect(conf.transports[:winrm]['ssl']).to be true
          expect(conf.transports[:winrm]['ssl-verify']).to be true
        end

        it 'uses the configured transport' do
          target = get_target(inventory, 'target')
          expect(target.protocol).to eq('winrm')
        end

        it 'only uses configured options for ssh' do
          target = get_target(inventory, 'ssh://target')
          expect(target.protocol).to eq('ssh')
          expect(target.user).to eq('messh')
          expect(target.password).to eq('youssh')
          expect(target.port).to eq('12345ssh')
          expect(target.options).to eq(
            'connect-timeout' => 3,
            'tty' => true,
            'host-key-check' => false,
            'private-key' => "anything",
            'tmpdir' => "/ssh",
            'run-as' => "root",
            'sudo-password' => "nothing",
            'password' => 'youssh',
            'port' => '12345ssh',
            "load-config" => true,
            'user' => 'messh'
          )
        end

        it 'only uses configured options for winrm' do
          target = get_target(inventory, 'winrm://target')
          expect(target.protocol).to eq('winrm')
          expect(target.user).to eq('mewinrm')
          expect(target.password).to eq('youwinrm')
          expect(target.port).to eq('12345winrm')
          expect(target.options).to eq(
            'connect-timeout' => 5,
            'ssl' => false,
            'ssl-verify' => false,
            'tmpdir' => "/winrm",
            'cacert' => "winrm.pem",
            'extensions' => ".py",
            'password' => 'youwinrm',
            'port' => '12345winrm',
            'user' => 'mewinrm',
            'file-protocol' => 'winrm'
          )
        end

        it 'only uses configured options for pcp' do
          target = get_target(inventory, 'pcp://target')
          expect(target.protocol).to eq('pcp')
          expect(target.user).to be nil
          expect(target.password).to be nil
          expect(target.port).to be nil
          expect(target.options).to eq(
            'task-environment' => "prod",
            'service-url' => "https://master",
            'cacert' => "pcp.pem",
            'token-file' => "token"
          )
        end
      end
    end
  end

  context 'with localhost' do
    context 'with no additional config' do
      let(:data) {
        { 'targets' => ['localhost'] }
      }

      let(:inventory) { Bolt::Inventory::Inventory2.new(data) }

      it 'adds magic config options' do
        target = get_target(inventory, 'localhost')
        expect(target.protocol).to eq('local')
        expect(target.options['interpreters']).to include('.rb' => RbConfig.ruby)
        expect(target.features).to include('puppet-agent')
      end
    end

    context 'with config' do
      let(:data) {
        { 'name' => 'locomoco',
          'targets' => ['localhost'],
          'config' => {
            'transport' => 'local',
            'local' => {
              'interpreters' => { '.rb' => '/foo/ruby' }
            }
          } }
      }
      let(:inventory) { Bolt::Inventory::Inventory2.new(data) }

      it 'does not override config options' do
        target = get_target(inventory, 'localhost')
        expect(target.protocol).to eq('local')
        expect(target.options['interpreters']).to include('.rb' => '/foo/ruby')
        expect(target.features).to include('puppet-agent')
      end
    end

    context 'with non-local transport' do
      let(:data) {
        { 'targets' => [{
          'name' => 'localhost',
          'config' => {
            'transport' => 'ssh',
            'ssh' => {
              'interpreters' => { '.rb' => '/foo/ruby' }
            }
          }
        }] }
      }
      let(:inventory) { Bolt::Inventory::Inventory2.new(data) }
      it 'does not set magic config' do
        target = get_target(inventory, 'localhost')
        expect(target.protocol).to eq('ssh')
        expect(target.options['interpreters']).to include('.rb' => '/foo/ruby')
        expect(target.features).to include('puppet-agent')
      end
    end
  end

  context 'with lookup_targets plugins' do
    let(:data) {
      {
        'version' => 2,
        'groups' => [
          { 'name' => 'group1',
            'targets' => [
              { 'name' => 'node1',
                'config' => { 'transport' => 'winrm' } }
            ] },
          { 'name' => 'group2',
            'targets' => [
              { '_plugin' => 'test_plugin' }
            ] },
          { 'name' => 'group3',
            'targets' => [
              { 'name' => 'node2',
                'config' => { 'transport' => 'winrm' } }
            ] }
        ]
      }
    }

    let(:lookup) {
      [
        { 'name' => 'node1',
          'config' => { 'transport' => 'remote' } },
        { 'name' => 'node2',
          'config' => { 'transport' => 'remote' } }
      ]
    }

    let(:hooks) { ['inventory_targets'] }

    let(:plugins) do
      plugins = Bolt::Plugin.new(nil)
      plugin = double('plugin')
      allow(plugin).to receive(:name).and_return('test_plugin')
      allow(plugin).to receive(:inventory_targets).and_return(lookup)
      expect(plugin).to receive(:hooks).and_return(hooks)
      plugins.add_plugin(plugin)
      plugins
    end

    it 'does not override a preceding definition' do
      target = get_target(inventory, 'node1')
      expect(target.transport).to eq('winrm')
    end

    it 'does override a later defintion' do
      target = get_target(inventory, 'node2')
      expect(target.transport).to eq('remote')
    end
  end
end
