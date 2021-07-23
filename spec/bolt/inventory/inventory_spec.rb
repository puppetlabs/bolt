# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/config'
require 'bolt/inventory'
require 'bolt/plugin'

describe Bolt::Inventory::Inventory do
  include BoltSpec::Config

  def get_target(inventory, name, alia = nil)
    targets = inventory.get_targets(alia || name)
    expect(targets.size).to eq(1)
    expect(targets[0].name).to eq(name)
    targets[0]
  end

  let(:pal)          { nil }
  let(:config)       { make_config }
  let(:plugins)      { Bolt::Plugin.setup(config, pal) }
  let(:target_name)  { "example.com" }
  let(:target_entry) { target_name }
  let(:targets)      { [target_entry] }
  let(:groups)       { [] }
  let(:transports)   { config.transports }
  let(:transport)    { config.transport }

  let(:data) do
    {
      'version' => 2,
      'targets' => targets,
      'groups' => groups
    }
  end

  let(:inventory) { Bolt::Inventory.create_version(data, transport, transports, plugins) }

  it 'creates simple inventory' do
    expect(inventory.class).to eq(Bolt::Inventory::Inventory)
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
            'port' => 2222
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
                'port' => 2223
              }
            } }
        ]
      }
    }

    describe :validate do
      it 'accepts empty inventory' do
        expect(Bolt::Inventory::Inventory.new({}, transport, transports, plugins).validate).to be_nil
      end

      it 'accepts non-empty inventory' do
        expect(Bolt::Inventory::Inventory.new(data, transport, transports, plugins).validate).to be_nil
      end

      it 'fails with unnamed groups' do
        data = { 'groups' => [{}] }
        expect {
          Bolt::Inventory::Inventory.new(data, transport, transports, plugins).validate
        }.to raise_error(Bolt::Inventory::ValidationError, /Group does not have a name/)
      end

      it 'fails with unamed targets' do
        data = { 'targets' => [{ 'name' => '' }] }

        expect {
          Bolt::Inventory::Inventory.new(data, transport, transports, plugins)
        }.to raise_error(Bolt::Inventory::ValidationError, /No name or uri for target/)
      end

      it 'fails with duplicate groups' do
        data = { 'groups' => [{ 'name' => 'group1' }, { 'name' => 'group1' }] }
        expect {
          Bolt::Inventory::Inventory.new(data, transport, transports, plugins).validate
        }.to raise_error(Bolt::Inventory::ValidationError, /Tried to redefine group group1/)
      end
    end

    describe :collect_groups do
      it 'finds the all group with an empty inventory' do
        inventory = Bolt::Inventory::Inventory.new({}, transport, transports, plugins)
        expect(inventory.get_targets('all')).to eq([])
      end

      it 'finds the all group with a non-empty inventory' do
        inventory = Bolt::Inventory::Inventory.new(data, transport, transports, plugins)
        targets = inventory.get_targets('all')
        expect(targets.size).to eq(9)
      end

      it 'finds targets in a subgroup' do
        inventory = Bolt::Inventory::Inventory.new(data, transport, transports, plugins)
        targets = inventory.get_targets('group2')
        target_names = targets.map(&:name)
        expect(target_names).to eq(%w[target6 target7 ssh://target8 target9])
      end
    end

    context 'with an empty config' do
      let(:inventory) { Bolt::Inventory::Inventory.new({}, transport, transports, plugins) }
      let(:target) { inventory.get_targets('notarget')[0] }

      it 'should accept an empty file' do
        expect(inventory).to be
      end

      it 'the all group should be empty' do
        expect(inventory.get_targets('all')).to eq([])
      end

      it 'should have the default transport' do
        expect(target.transport).to eq('ssh')
      end
    end

    context 'with config' do
      let(:data) do
        {
          'transport' => 'winrm',
          'winrm' => {
            'ssl'        => false,
            'ssl-verify' => false
          }
        }
      end
      let(:config)    { make_config(data) }
      let(:inventory) { Bolt::Inventory::Inventory.new({}, config.transport, config.transports, plugins) }
      let(:target)    { inventory.get_targets('notarget')[0] }

      it 'should have the correct transport' do
        expect(target.transport).to eq('winrm')
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
        let(:inventory) { Bolt::Inventory::Inventory.new({}, transport, transports, plugins) }

        it 'should parse a single target URI' do
          name = 'notarget'
          targets = inventory.get_targets(name).map(&:uri)
          expect(targets).to eq([name])
        end

        it 'should parse an array of target URIs' do
          names = ['pcp://a', 'winrm://b', 'c']
          targets = inventory.get_targets(names).map(&:uri)
          expect(targets).to eq(names)
        end

        it 'should parse a nested array of target URIs and Targets' do
          names = [['a'], inventory.get_target('b'), ['c', 'ssh://d']]
          uris = ['a', 'b', 'c', 'ssh://d']
          targets = inventory.get_targets(names).map(&:uri)
          expect(targets).to eq(uris)
        end

        it 'should split a comma-separated list of target URIs' do
          ts = ['ssh://a', 'winrm://b:5000', 'u:p@c']
          names = 'ssh://a, winrm://b:5000, u:p@c'
          targets = inventory.get_targets(names).map(&:uri)
          expect(targets).to eq(ts)
        end

        it 'should always add new targets to the `all` group' do
          ts = ['ssh://a', 'winrm://b:5000', 'u:p@c']
          names = 'ssh://a, winrm://b:5000, u:p@c'
          inventory.get_targets(names)
          targets = inventory.get_targets('all').map(&:uri)
          expect(targets).to eq(ts)
        end

        it 'should fail for unknown URI schemes' do
          expect {
            inventory.get_targets('z://foo')
          }.to raise_error(Bolt::UnknownTransportError, %r{Unknown transport z found for z://foo})
        end
      end

      context 'non-empty inventory' do
        let(:inventory) { Bolt::Inventory::Inventory.new(data, transport, transports, plugins) }

        it 'should parse an array of target URI and group name' do
          targets = inventory.get_targets(%w[a group1]).map(&:name)
          expect(targets).to eq(%w[a target4 target5 target6 target7])
        end

        it 'should split a comma-separated list of target URI and group name' do
          matched_targets = %w[target4 target5 target6 target7 ssh://target8]
          targets = inventory.get_targets('group1,ssh://target8').map(&:name)
          expect(targets).to eq(matched_targets)
        end

        it 'should match wildcard selectors' do
          targets = inventory.get_targets('target*')
          expect(targets.map(&:name).sort).to eq(%w[target1 target2 target3 target4 target5 target6 target7 target9])
        end

        it 'should fail if wildcard selector matches nothing' do
          expect {
            inventory.get_targets('*target')
          }.to raise_error(Bolt::Inventory::Inventory::WildcardError,
                           /Found 0 targets matching wildcard pattern \*target/)
        end
      end

      context 'with data in the group' do
        let(:inventory) { Bolt::Inventory::Inventory.new(data, transport, transports, plugins) }

        it 'should use value from lowest target definition' do
          expect(get_target(inventory, 'target4').user).to eq('me')
        end

        it 'should use values from the lowest group' do
          expect(get_target(inventory, 'target4').options.to_h).to include('host-key-check' => true)
        end

        it 'should include values from parents' do
          expect(get_target(inventory, 'target4').port).to eq(2222)
        end

        it 'should use values from the first group' do
          expect(get_target(inventory, 'target6').options.to_h).to include('host-key-check' => true)
        end

        it 'should prefer values from a target over an earlier group' do
          expect(get_target(inventory, 'target6').user).to eq('someone')
        end

        it 'should use values from matching groups' do
          expect(get_target(inventory, 'ssh://target8').port).to eq(2223)
        end

        it 'should only return config for exact matches' do
          target_names = inventory.get_targets('target8').map(&:name)
          expect(target_names).to eq(['target8'])
        end
      end

      context 'with targets at the top level' do
        let(:data) {
          {
            'targets' => [
              'target1',
              { 'uri' => 'target2' },
              { 'uri' => 'target3',
                'config' => {
                  'ssh' => {
                    'data' => true,
                    'port' => 2224
                  }
                } }
            ]
          }
        }
        let(:inventory) { Bolt::Inventory::Inventory.new(data, transport, transports, plugins) }

        it 'should initialize' do
          expect(inventory).to be
        end

        it 'should return {} for a string target' do
          expect(get_target(inventory, 'target1').options.to_h).to eq(Bolt::Config::Transport::SSH::DEFAULTS)
        end

        it 'should return {} for a hash target with no config' do
          expect(get_target(inventory, 'target2').options.to_h).to eq(Bolt::Config::Transport::SSH::DEFAULTS)
        end

        it 'should return config for the target' do
          target = get_target(inventory, 'target3')
          expect(target.options.to_h).to eq(Bolt::Config::Transport::SSH::DEFAULTS.merge('port' => 2224))
          expect(target.port).to eq(2224)
        end

        it 'should return the raw target for an unknown target' do
          targets = inventory.get_targets('target5').map(&:uri)
          expect(targets).to eq(['target5'])
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
        let(:inventory) { Bolt::Inventory::Inventory.new(data, transport, transports, plugins) }

        it 'should return group config for string targets' do
          target = get_target(inventory, 'target1')
          expect(target.options.to_h).to include('host-key-check' => false)
          expect(target.user).to eq('you')
        end

        it 'should return group config for array targets' do
          target = get_target(inventory, 'target2')
          expect(target.options.to_h).to include('host-key-check' => false)
          expect(target.user).to eq('you')
        end

        it 'should merge config for from targets' do
          target = get_target(inventory, 'target3')
          expect(target.options.to_h).to include('host-key-check' => false)
          expect(target.user).to eq('me')
        end
      end

      context 'with config errors in data' do
        let(:inventory) { Bolt::Inventory::Inventory.new(data, transport, transports, plugins) }

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
              'config' => { 'transport' => 'winrm', 'winrm' => { 'connect-timeout' => '10' } }
            }
          }

          it 'fails validation' do
            expect { inventory.get_targets('target') }.to raise_error(Bolt::ValidationError)
          end
        end

        context 'disconnect-timeout' do
          let(:data) {
            {
              'targets' => ['target'],
              'config' => { 'ssh' => { 'disconnect-timeout' => '10' } }
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
              'config' => { 'transport' => 'winrm', 'winrm' => { 'ssl' => 'true' } }
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
              'config' => { 'transport' => 'winrm', 'winrm' => { 'ssl-verify' => 'true' } }
            }
          }

          it 'fails validation' do
            expect { inventory.get_targets('target') }.to raise_error(Bolt::ValidationError)
          end
        end

        context 'basic-auth-only' do
          let(:data) {
            {
              'targets' => ['target'],
              'config' => { 'transport' => 'winrm', 'winrm' => { 'basic-auth-only' => 'true' } }
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
        let(:inventory) { Bolt::Inventory::Inventory.new(data, transport, transports, plugins) }

        it 'should return group config for an alias' do
          target = get_target(inventory, 'target2', 'alias1')
          expect(target.options.to_h).to include('host-key-check' => false)
          expect(target.user).to eq('you')
        end

        it 'should merge config from targets' do
          target = get_target(inventory, 'target3', 'alias3')
          expect(target.options.to_h).to include('host-key-check' => false)
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
            'port' => 12345,
            'private-key' => 'anything',
            'ssl' => true,
            'ssl-verify' => false,
            'host-key-check' => false,
            'connect-timeout' => transport.size,
            'tmpdir' => '/' + transport,
            'run-as' => 'root',
            'tty' => true,
            'sudo-password' => 'nothing',
            'extensions' => ['.py'],
            'service-url' => 'https://master',
            'cacert' => transport + '.pem',
            'token-file' => 'token',
            'task-environment' => 'prod',
            'basic-auth-only' => true
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
        let(:inventory) { Bolt::Inventory::Inventory.new(data, transport, transports, plugins) }

        before(:each) do
          allow(Bolt::Util).to receive(:validate_file).and_return(true)
        end

        it 'should not modify existing config' do
          get_target(inventory, 'ssh://target')
          expect(conf.transport).to eq('ssh')
          expect(conf.transports['ssh']['host-key-check']).to be nil
          expect(conf.transports['winrm']['ssl']).to be true
          expect(conf.transports['winrm']['ssl-verify']).to be true
          expect(conf.transports['winrm']['basic-auth-only']).to be false
        end

        it 'uses the configured transport' do
          target = get_target(inventory, 'target')
          expect(target.transport).to eq('winrm')
        end

        it 'only uses configured options for ssh' do
          target = get_target(inventory, 'ssh://target')
          expect(target.transport).to eq('ssh')
          expect(target.user).to eq('messh')
          expect(target.password).to eq('youssh')
          expect(target.port).to eq(12345)
          expect(target.options.to_h).to include(
            'connect-timeout' => 3,
            'disconnect-timeout' => 5,
            'tty' => true,
            'host-key-check' => false,
            'tmpdir' => "/ssh",
            'run-as' => "root",
            'sudo-password' => "nothing",
            'password' => 'youssh',
            'port' => 12345,
            "load-config" => true,
            'user' => 'messh',
            'private-key' => /anything\z/
          )
        end

        it 'only uses configured options for winrm' do
          target = get_target(inventory, 'winrm://target')
          expect(target.transport).to eq('winrm')
          expect(target.user).to eq('mewinrm')
          expect(target.password).to eq('youwinrm')
          expect(target.port).to eq(12345)
          expect(target.options.to_h).to include(
            'connect-timeout' => 5,
            'ssl' => true,
            'ssl-verify' => false,
            'tmpdir' => "/winrm",
            'extensions' => [".py"],
            'password' => 'youwinrm',
            'port' => 12345,
            'user' => 'mewinrm',
            'file-protocol' => 'winrm',
            'cacert' => /winrm.pem\z/,
            'basic-auth-only' => true
          )
        end

        it 'only uses configured options for pcp' do
          target = get_target(inventory, 'pcp://target')
          expect(target.transport).to eq('pcp')
          expect(target.user).to be nil
          expect(target.password).to be nil
          expect(target.port).to be nil
          expect(target.options.to_h).to include(
            'task-environment' => "prod",
            'service-url' => "https://master",
            'cacert' => /pcp.pem\z/,
            'token-file' => /token\z/
          )
        end
      end
    end

    describe 'get_target' do
      context 'empty inventory' do
        let(:inventory) { Bolt::Inventory::Inventory.new({}, transport, transports, plugins) }

        it 'should parse a single target URI' do
          name = 'notarget'
          target = inventory.get_target(name)
          expect(target.name).to eq(name)
        end

        it 'should error when an array of targets is requested' do
          names = ['pcp://a', 'winrm://b', 'c']
          expect {
            inventory.get_target(names)
          }.to raise_error(Bolt::Inventory::ValidationError, "'#{names}' refers to 3 targets")
        end

        it 'should fail for unknown URI schemes' do
          expect {
            inventory.get_target('z://foo')
          }.to raise_error(Bolt::UnknownTransportError, %r{Unknown transport z found for z://foo})
        end
      end

      context 'non-empty inventory' do
        let(:inventory) { Bolt::Inventory::Inventory.new(data, transport, transports, plugins) }

        it 'a target that does not exists in inventory is created and added to the all group' do
          existing_target_names = inventory.get_targets('all').map(&:name)
          new_target = inventory.get_target('new')
          updated_target_names = inventory.get_targets('all').map(&:name)
          expect(new_target.name).to eq('new')
          expect(updated_target_names - existing_target_names).to eq(%w[new])
        end

        it 'retrieves an existing target from inventory with its existing data' do
          existing_target_name = 'target7'
          existing_target = inventory.get_target(existing_target_name)
          expect(existing_target.name).to eq(existing_target_name)
          expect(existing_target.options['port']).to eq(2223)
        end

        it 'should match wildcard selectors' do
          existing_target_name = 'target7'
          target = inventory.get_target('*7')
          expect(target.name).to eq(existing_target_name)
        end
      end

      context 'with data in the group' do
        let(:inventory) { Bolt::Inventory::Inventory.new(data, transport, transports, plugins) }

        it 'should use value from lowest target definition' do
          expect(inventory.get_target('target4').user).to eq('me')
        end

        it 'should use values from the left most group' do
          expect(inventory.get_target('target4').options.to_h).to include('host-key-check' => true)
        end

        it 'should include values from parents' do
          expect(inventory.get_target('target4').port).to eq(2222)
        end

        it 'should use values from the first group' do
          expect(inventory.get_target('target6').options.to_h).to include('host-key-check' => true)
        end

        it 'should prefer values from a target over an earlier group' do
          expect(inventory.get_target('target6').user).to eq('someone')
        end

        it 'should use values from matching groups' do
          expect(inventory.get_target('ssh://target8').port).to eq(2223)
        end
      end

      context 'with targets at the top level' do
        let(:data) {
          {
            'targets' => [
              'target1',
              { 'uri' => 'target2' },
              { 'uri' => 'target3',
                'config' => {
                  'ssh' => {
                    'data' => true,
                    'port' => 2224
                  }
                } }
            ]
          }
        }
        let(:inventory) { Bolt::Inventory::Inventory.new(data, transport, transports, plugins) }

        it 'should return {} for a string target' do
          target = inventory.get_target('target1')
          expect(target.options.to_h).to include(Bolt::Config::Transport::SSH::DEFAULTS)
          expect(target.config).to eq({})
        end

        it 'should return {} for a hash target with no config' do
          target = inventory.get_target('target2')
          expect(target.options.to_h).to include(Bolt::Config::Transport::SSH::DEFAULTS)
          expect(target.config).to eq({})
        end

        it 'should return config for the target' do
          target = inventory.get_target('target3')
          expect(target.options.to_h).to eq(Bolt::Config::Transport::SSH::DEFAULTS.merge('port' => 2224))
          expect(target.port).to eq(2224)
          expect(target.config).to eq("ssh" => { "data" => true, "port" => 2224 })
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
        let(:inventory) { Bolt::Inventory::Inventory.new(data, transport, transports, plugins) }

        it 'should return group config for string targets' do
          target = inventory.get_target('target1')
          expect(target.options.to_h).to include('host-key-check' => false)
          expect(target.user).to eq('you')
          expect(target.config).to eq("ssh" => { "user" => "you", "host-key-check" => false })
        end

        it 'should return group config for hash targets' do
          target = inventory.get_target('target2')
          expect(target.options.to_h).to include('host-key-check' => false)
          expect(target.user).to eq('you')
          expect(target.config).to eq("ssh" => { "user" => "you", "host-key-check" => false })
        end

        it 'should merge config for from targets' do
          target = inventory.get_target('target3')
          expect(target.options.to_h).to include('host-key-check' => false)
          expect(target.user).to eq('me')
          expect(target.config).to eq("ssh" => { "user" => "me", "host-key-check" => false })
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
              { 'name' => 'group1', 'targets' => %w[target1] }
            ],
            'config' => {
              'ssh' => {
                'user' => 'you',
                'host-key-check' => false
              }
            }
          }
        }
        let(:inventory) { Bolt::Inventory::Inventory.new(data, transport, transports, plugins) }

        it 'should return group config for an alias' do
          target = inventory.get_target('alias1')
          expect(target.options.to_h).to include('host-key-check' => false)
          expect(target.user).to eq('you')
          expect(target.config).to eq("ssh" => { "user" => "you", "host-key-check" => false })
        end

        it 'should merge config from targets' do
          target = inventory.get_target('alias3')
          expect(target.options.to_h).to include('host-key-check' => false)
          expect(target.config).to eq("ssh" => { "user" => "me", "host-key-check" => false })
        end

        it 'should resolve target labels as long as a single target is returned' do
          target = inventory.get_target('group1')
          expect(target.name).to eq('target1')
          expect(target.user).to eq('you')
          expect(target.config).to eq("ssh" => { "user" => "you", "host-key-check" => false })
        end
      end

      context 'with all options in the config' do
        def common_data(transport)
          {
            'user' => 'me' + transport,
            'password' => 'you' + transport,
            'port' => 12345,
            'private-key' => 'anything',
            'ssl' => false,
            'ssl-verify' => false,
            'host-key-check' => false,
            'connect-timeout' => transport.size,
            'tmpdir' => '/' + transport,
            'run-as' => 'root',
            'tty' => true,
            'sudo-password' => 'nothing',
            'extensions' => ['.py'],
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
        let(:inventory) { Bolt::Inventory::Inventory.new(data, transport, transports, plugins) }

        before(:each) do
          allow(Bolt::Util).to receive(:validate_file).and_return(true)
        end

        it 'should not modify existing config' do
          inventory.get_target('ssh://target')
          expect(conf.transport).to eq('ssh')
          expect(conf.transports['ssh']['load-config']).to be true
          expect(conf.transports['winrm']['ssl']).to be true
          expect(conf.transports['winrm']['ssl-verify']).to be true
        end

        it 'uses the configured transport' do
          target = inventory.get_target('target')
          expect(target.transport).to eq('winrm')
          expect(target.config).to eq(data['config'])
        end

        it 'only uses configured options for ssh' do
          target = inventory.get_target('ssh://target')
          expect(target.transport).to eq('ssh')
          expect(target.user).to eq('messh')
          expect(target.password).to eq('youssh')
          expect(target.port).to eq(12345)
          expect(target.options.to_h).to include(
            'connect-timeout' => 3,
            'disconnect-timeout' => 5,
            'tty' => true,
            'host-key-check' => false,
            'private-key' => /anything\z/,
            'tmpdir' => "/ssh",
            'run-as' => "root",
            'sudo-password' => "nothing",
            'password' => 'youssh',
            'port' => 12345,
            "load-config" => true,
            'user' => 'messh'
          )
        end

        it 'only uses configured options for winrm' do
          target = inventory.get_target('winrm://target')
          expect(target.transport).to eq('winrm')
          expect(target.user).to eq('mewinrm')
          expect(target.password).to eq('youwinrm')
          expect(target.port).to eq(12345)
          expect(target.options.to_h).to include(
            'connect-timeout' => 5,
            'ssl' => false,
            'ssl-verify' => false,
            'tmpdir' => "/winrm",
            'cacert' => /winrm.pem\z/,
            'extensions' => [".py"],
            'password' => 'youwinrm',
            'port' => 12345,
            'user' => 'mewinrm',
            'file-protocol' => 'winrm'
          )
        end

        it 'only uses configured options for pcp' do
          target = inventory.get_target('pcp://target')
          expect(target.transport).to eq('pcp')
          expect(target.user).to be nil
          expect(target.password).to be nil
          expect(target.port).to be nil
          expect(target.options.to_h).to include(
            'task-environment' => "prod",
            'service-url' => "https://master",
            'cacert' => /pcp.pem\z/,
            'token-file' => /token\z/
          )
        end
      end
    end
  end

  describe 'set_config' do
    context 'when updating existing values' do
      let(:data) {
        { 'groups' => [{
          'name' => 'test',
          'targets' => [{
            'name' => 'target',
            'config' => {
              'transport' => 'ssh',
              'ssh' => {
                'interpreters' => { '.rb' => '/foo/ruby' },
                'password' => 'sshpass'
              }
            }
          }],
          'config' => { 'ssh' => { 'disconnect-timeout' => 11 } }
        }] }
      }
      let(:inventory) { Bolt::Inventory::Inventory.new(data, transport, transports, plugins) }
      let(:expected_options) {
        { "batch-mode" => true,
          "connect-timeout" => 10,
          "tty" => false,
          "load-config" => true,
          "disconnect-timeout" => 11,
          'login-shell' => 'bash',
          'cleanup' => true,
          "password" => 'sshpass',
          "interpreters" => { ".rb" => "/foo/ruby" } }
      }
      let(:expected_config) {
        {
          "ssh" => {
            "disconnect-timeout" => 11,
            "interpreters" => { ".rb" => "/foo/ruby" },
            "password" => "sshpass"
          },
          "transport" => "ssh"
        }
      }

      it 'sets config on a target' do
        target = inventory.get_target('target')
        expect(target.transport).to eq('ssh')
        expect(target.password).to eq('sshpass')
        expect(target.config).to eq(expected_config)
        inventory.set_config(target, 'transport', 'local')
        expect(target.transport).to eq('local')
        expect(target.config).to eq(expected_config.merge('transport' => 'local'))
      end

      it 'overrides a default value not specified in inventory' do
        target = inventory.get_target('target')
        expect(target.options.to_h).to eq(expected_options)
        expect(target.config).to eq(expected_config)
        inventory.set_config(target, %w[ssh tty], true)
        expected_config['ssh']['tty'] = true
        expect(target.config).to eq(expected_config)
      end

      it 'sets a nested config value without disrupting other values' do
        target = inventory.get_target('target')
        expect(target.options.to_h).to eq(expected_options)
        expect(target.config).to eq(expected_config)
        inventory.set_config(target, ['ssh', 'interpreters', '.py'], '/foo/python')
        expected_options["interpreters"].merge!(".py" => "/foo/python")
        expected_config['ssh']['interpreters'].merge!(".py" => "/foo/python")
        expect(target.options.to_h).to eq(expected_options)
        expect(target.config).to eq(expected_config)
      end

      it 'overrides entire config when an key_or_key_path is an empty string' do
        target = inventory.get_target('target')
        expect(target.options.to_h).to eq(expected_options)
        expect(target.config).to eq(expected_config)
        inventory.set_config(target, '', 'transport' => 'winrm', 'winrm' => { 'password' => 'winrmpass' })
        expect(target.transport).to eq('winrm')
        expect(target.password).to eq('winrmpass')
        winrm_conf = { "password" => "winrmpass",
                       "ssl" => true,
                       "ssl-verify" => true,
                       "file-protocol" => "winrm",
                       "connect-timeout" => 10 }
        expect(target.options.to_h).to include(winrm_conf)
        expected_config['transport'] = 'winrm'
        expected_config['winrm'] = { 'winrm' => { 'password' => 'winrmpass' } }
      end
    end
  end

  describe 'add_facts' do
    let(:target) { inventory.get_target('foo') }
    let(:facts) { { 'foo' => 'bar' } }

    it 'returns Target object' do
      result = inventory.add_facts(target, facts)
      expect(target).to eq(result)
      expect(result.facts).to eq(facts)
    end
  end

  describe 'add_to_group' do
    context 'when updating existing values' do
      let(:data) {
        { 'groups' => [{
          'name' => 'test',
          'targets' => [{
            'name' => 'target',
            'config' => {
              'transport' => 'ssh'
            }
          }],
          'config' => { 'ssh' => { 'disconnect-timeout' => 11 } }
        }] }
      }

      let(:inventory) { Bolt::Inventory::Inventory.new(data, transport, transports, plugins) }

      it 'adds target to a group and inherets config' do
        target = inventory.get_target('new-target')
        expect(target.transport).to eq('ssh')
        expect(target.options.to_h).to include('disconnect-timeout' => 5)
        expect(target.config).to eq({})
        inventory.add_to_group([target], 'test')
        expect(target.options.to_h).to include('disconnect-timeout' => 11)
        expect(target.config).to eq('ssh' => { 'disconnect-timeout' => 11 })
        expect(inventory.get_targets('test').map(&:name)).to eq(%w[target new-target])
      end
    end
  end

  describe 'remove_from_group' do
    let(:data) {
      {
        'groups' => [{
          'name' => 'test',
          'targets' => ['target'],
          'features' => ['foo']
        }],
        'features' => ['bar']
      }
    }

    let(:inventory) { Bolt::Inventory::Inventory.new(data, transport, transports, plugins) }

    it 'removes target from a group and disinherits config' do
      target = get_target(inventory, 'target')
      expect(target.features).to match_array(%w[foo bar])
      inventory.remove_from_group([target], 'test')
      expect(target.features).to match_array(%w[bar])
    end
  end

  context 'with lookup_targets plugins' do
    let(:data) {
      {
        'version' => 2,
        'groups' => [
          { 'name' => 'group1',
            'targets' => [
              { 'name' => 'target1',
                'config' => { 'transport' => 'winrm' } }
            ] },
          { 'name' => 'group2',
            'targets' => [
              { '_plugin' => 'test_plugin' }
            ] },
          { 'name' => 'group3',
            'targets' => [
              { 'name' => 'target2',
                'config' => { 'transport' => 'winrm' } }
            ] }
        ]
      }
    }

    let(:lookup) {
      [
        { 'name' => 'target1',
          'config' => { 'transport' => 'remote' } },
        { 'name' => 'target2',
          'config' => { 'transport' => 'remote' } }
      ]
    }

    let(:plugins) do
      plugins = Bolt::Plugin.setup(config, pal)
      plugin = double('plugin')
      allow(plugin).to receive(:name).and_return('test_plugin')
      allow(plugin).to receive(:hooks).and_return([:resolve_reference])
      allow(plugin).to receive(:resolve_reference).and_return(lookup)
      plugins.add_plugin(plugin)
      plugins
    end

    it 'does not override a preceding definition' do
      target = get_target(inventory, 'target1')
      expect(target.transport).to eq('winrm')
    end

    it 'does override a later defintion' do
      target = get_target(inventory, 'target2')
      expect(target.transport).to eq('remote')
    end
  end

  context 'when using inventory show' do
    let(:data) {
      { 'version' => 2,
        'groups' => [{
          'name' => 'group1',
          'targets' => [{
            'uri' => 'foo',
            'alias' => %w[bar]
          }]
        }, {
          'name' => 'group2',
          'targets' => [{
            'uri' => 'foo',
            'alias' => %w[baz],
            'config' => { 'ssh' => { 'disconnect-timeout' => 100 } },
            'facts' => { 'foo' => 'bar' }
          }]
        }] }
    }

    let(:inventory) { Bolt::Inventory.create_version(data, transport, transports, plugins) }
    let(:target) { get_target(inventory, 'foo') }
    let(:expected_data) {
      { 'name' => 'foo',
        'uri' => 'foo',
        'alias' => %w[baz bar],
        'config' => {
          'transport' => 'ssh',
          'ssh' => {
            'batch-mode' => true,
            'connect-timeout' => 10,
            'tty' => false,
            'load-config' => true,
            'disconnect-timeout' => 100,
            'login-shell' => 'bash',
            'cleanup' => true
          }
        },
        'vars' => {},
        'facts' => { 'foo' => 'bar' },
        'features' => [],
        'groups' => %w[group1 group2 all],
        'plugin_hooks' => {
          'puppet_library' => { 'plugin' => 'puppet_agent', 'stop_service' => true }
        } }
    }

    it 'target detail method returns expected munged config from inventory' do
      expect(target.detail).to eq(expected_data)
    end
  end

  describe 'creating a target from a hash' do
    let(:data) do
      {
        'groups' => [
          {
            'name' => 'group1',
            'targets' => [
              {
                'name' => 'target1',
                'alias' => ['alias1']
              }
            ]
          }
        ]
      }
    end

    it 'errors when there is a group/target name conflict' do
      hash = { 'name' => 'group1' }
      expect { inventory.create_target_from_hash(hash) }.to raise_error(
        Bolt::Inventory::ValidationError, /Target name group1 conflicts with group of the same name/
      )
      expect(inventory.target_names).not_to include('group1')
    end

    it 'errors when there is a group/alias conflict' do
      hash = { 'name' => 'target2', 'alias' => ['group1'] }
      expect { inventory.create_target_from_hash(hash) }.to raise_error(
        Bolt::Inventory::ValidationError, /Alias group1 conflicts with group of the same name/
      )
      expect(inventory.target_names).not_to include('target2')
    end

    it 'errors when there is a target/alias conflict' do
      hash = { 'name' => 'target2', 'alias' => ['target1'] }
      expect { inventory.create_target_from_hash(hash) }.to raise_error(
        Bolt::Inventory::ValidationError, /Alias target1 conflicts with target of the same name/
      )
      expect(inventory.target_names).not_to include('target2')
    end

    it 'errors when there is an alias conflict between targets' do
      hash = { 'name' => 'target2', 'alias' => ['alias1'] }
      expect { inventory.create_target_from_hash(hash) }.to raise_error(
        Bolt::Inventory::ValidationError, /Alias alias1 refers to multiple targets: target1 and target2/
      )
      expect(inventory.target_names).not_to include('target2')
    end

    it 'overwrites an existing target with the same alias' do
      hash = { 'name' => 'target2', 'alias' => ['alias2'] }
      expect { inventory.create_target_from_hash(hash) }.not_to raise_error
    end

    it 'picks up localhost default transport' do
      hash = { 'name' => 'localhost' }
      target = inventory.create_target_from_hash(hash)
      expect(target.transport).to eq('local')
    end
  end

  context 'when the transport config contains keys that resolved to nil' do
    let(:transport_config) do
      {
        'transport' => 'ssh',
        'ssh' => {
          'user' => {
            '_plugin' => 'mock_plugin'
          },
          'private-key' => {
            'key-data' => {
              '_plugin' => 'mock_plugin'
            }
          },
          'password' => 'foo_password'
        }
      }
    end

    before(:each) do
      mock_plugin = double('mock_plugin')
      allow(mock_plugin).to receive(:name).and_return('mock_plugin')
      allow(mock_plugin).to receive(:hooks).and_return([:resolve_reference])
      allow(mock_plugin).to receive(:resolve_reference).and_return(nil)
      plugins.add_plugin(mock_plugin)
    end

    context 'for a target' do
      let(:targets) do
        [
          {
            'name'   => 'test',
            'config' => transport_config
          }
        ]
      end

      it 'deletes nil-resolved keys' do
        target = inventory.get_targets('test').first
        expect(target.config['ssh']).not_to include('user')
        expect(target.config['ssh']).not_to include('private-key')
        expect(target.config['ssh']['password']).to eql('foo_password')
      end

      context 'when the transport config exclusively contains nil-resolved keys' do
        let(:transport_config) do
          { 'transport' => 'ssh', 'ssh' => { 'user' => { '_plugin' => 'mock_plugin' } } }
        end

        it 'returns an empty hash instead of deleting the transport config' do
          target = inventory.get_targets('test').first
          expect(target.config['ssh']).to eql({})
        end
      end
    end

    context 'for a group' do
      let(:groups) do
        [
          {
            'name'    => 'test_group',
            'config'  => transport_config,
            'targets' => ['test_target']
          }
        ]
      end

      it 'deletes nil-resolved keys' do
        target = inventory.get_targets('test_target').first
        expect(target.config['ssh']).not_to include('user')
        expect(target.config['ssh']).not_to include('private-key')
        expect(target.config['ssh']['password']).to eql('foo_password')
      end

      context 'when the transport config exclusively contains nil-resolved keys' do
        let(:transport_config) do
          { 'transport' => 'ssh', 'ssh' => { 'user' => { '_plugin' => 'mock_plugin' } } }
        end

        it 'returns an empty hash instead of deleting the transport config' do
          test_group = inventory.collect_groups['test_group']
          expect(test_group.group_data['config']['ssh']).to eql({})
        end
      end
    end
  end
end
