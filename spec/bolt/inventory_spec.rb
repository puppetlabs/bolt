require 'spec_helper'
require 'bolt_spec/config'
require 'bolt/inventory'

describe Bolt::Inventory do
  include BoltSpec::Config

  def targets(names)
    names.map { |n| Bolt::Target.new(n) }
  end

  def get_target(inventory, name)
    targets = inventory.get_targets(name)
    expect(targets.size).to eq(1)
    expect(targets[0].name).to eq(name)
    targets[0]
  end

  let(:data) {
    {
      'nodes' => [
        'node1',
        { 'name' =>  'node2' },
        { 'name' =>  'node3',
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
          'nodes' => [
            { 'name' => 'node4',
              'config' => {
                'ssh' => {
                  'user' => 'me'
                }
              } },
            'node5',
            'node6',
            'node7'
          ],
          'config' => {
            'ssh' => {
              'host-key-check' => true
            }
          } },
        { 'name' => 'group2',
          'nodes' => [
            { 'name' => 'node6',
              'config' => {
                'ssh' => { 'user' => 'someone' }
              } },
            'node7', 'ssh://node8'
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
      connect_timeout: 10,
      tty: false,
      host_key_check: true
    }
  }

  describe :validate do
    it 'accepts empty inventory' do
      expect(Bolt::Inventory.new({}).validate).to be_nil
    end

    it 'accepts non-empty inventory' do
      expect(Bolt::Inventory.new(data).validate).to be_nil
    end

    it 'fails with unnamed groups' do
      data = { 'groups' => [{}] }
      expect {
        Bolt::Inventory.new(data).validate
      }.to raise_error(Bolt::Inventory::ValidationError, /Group does not have a name/)
    end

    it 'fails with duplicate groups' do
      data = { 'groups' => [{ 'name' => 'group1' }, { 'name' => 'group1' }] }
      expect {
        Bolt::Inventory.new(data).validate
      }.to raise_error(Bolt::Inventory::ValidationError, /Tried to redefine group group1/)
    end

    it 'fails with deprecated property transport in global config' do
      data = { 'config' => { 'transports' => {} } }
      expect {
        Bolt::Inventory.new(data).validate
      }.to raise_error(Bolt::Inventory::ValidationError, /Group all contains invalid config/)
    end

    it 'fails with deprecated property transport in group config' do
      data = { 'groups' => [{ 'name' => 'group1', 'config' => { 'transports' => {} } }] }
      expect {
        Bolt::Inventory.new(data).validate
      }.to raise_error(Bolt::Inventory::ValidationError, /Group group1 contains invalid config/)
    end

    it 'fails with deprecated property transport in node config' do
      data = { 'nodes' => [{ 'name' => 'node1', 'config' => { 'transports' => {} } }] }
      expect {
        Bolt::Inventory.new(data).validate
      }.to raise_error(Bolt::Inventory::ValidationError, /Node node1 contains invalid config/)
    end
  end

  describe :collect_groups do
    it 'finds the all group with an empty inventory' do
      inventory = Bolt::Inventory.new({})
      inventory.collect_groups
      expect(inventory.get_targets('all')).to eq([])
    end

    it 'finds the all group with a non-empty inventory' do
      inventory = Bolt::Inventory.new(data)
      inventory.collect_groups
      targets = inventory.get_targets('all')
      expect(targets.size).to eq(8)
    end

    it 'finds nodes in a subgroup' do
      inventory = Bolt::Inventory.new(data)
      inventory.collect_groups
      targets = inventory.get_targets('group2')
      expect(targets).to eq(targets(%w[node6 node7 ssh://node8]))
    end
  end

  context 'with an empty config' do
    let(:inventory) { Bolt::Inventory.from_config(config) }
    let(:target) { inventory.get_targets('nonode')[0] }

    it 'should accept an empty file' do
      expect(inventory).to be
    end

    it 'should have the default protocol' do
      expect(target.protocol).to eq('ssh')
    end
  end

  context 'with config' do
    let(:inventory) {
      Bolt::Inventory.from_config(config(transport: 'winrm',
                                         transports: { winrm: {
                                           ssl: false
                                         } }))
    }
    let(:target) { inventory.get_targets('nonode')[0] }

    it 'should have use protocol' do
      expect(target.protocol).to eq('winrm')
    end

    it 'should not use ssl' do
      expect(target.options[:ssl]).to eq(false)
    end
  end

  describe 'get_targets' do
    context 'empty inventory' do
      let(:inventory) { Bolt::Inventory.from_config(config) }

      it 'should parse a single target URI' do
        name = 'nonode'
        expect(inventory.get_targets(name)).to eq(targets([name]))
      end

      it 'should parse an array of target URIs' do
        names = ['pcp://a', 'winrm://b', 'c']
        expect(inventory.get_targets(names)).to eq(targets(names))
      end

      it 'should parse a nested array of target URIs and Targets' do
        names = [['a'], Bolt::Target.new('b'), ['c', 'ssh://d']]
        expect(inventory.get_targets(names)).to eq(targets(['a', 'b', 'c', 'ssh://d']))
      end

      it 'should split a comma-separated list of target URIs' do
        ts = targets(['ssh://a', 'winrm://b:5000', 'u:p@c'])
        expect(inventory.get_targets('ssh://a, winrm://b:5000, u:p@c')).to eq(ts)
      end
    end

    context 'non-empty inventory' do
      let(:inventory) {
        inv = Bolt::Inventory.new(data)
        inv.collect_groups
        inv
      }

      it 'should parse an array of target URI and group name' do
        targets = inventory.get_targets(%w[a group1])
        expect(targets).to eq(targets(%w[a node4 node5 node6 node7]))
      end

      it 'should split a comma-separated list of target URI and group name' do
        matched_nodes = %w[node4 node5 node6 node7 ssh://node8]
        targets = inventory.get_targets('group1,ssh://node8')
        expect(targets).to eq(targets(matched_nodes))
      end

      it 'should match wildcard selectors' do
        targets = inventory.get_targets('node*')
        expect(targets).to eq(targets(%w[node1 node2 node3 node4 node5 node6 node7]))
      end

      it 'should fail if wildcard selector matches nothing' do
        expect {
          inventory.get_targets('*node')
        }.to raise_error(Bolt::Inventory::WildcardError, /Found 0 nodes matching wildcard pattern \*node/)
      end
    end

    context 'with data in the group' do
      let(:inventory) { Bolt::Inventory.new(data) }

      it 'should use value from lowest node definition' do
        expect(get_target(inventory, 'node4').user).to eq('me')
      end

      it 'should use values from the lowest group' do
        expect(get_target(inventory, 'node4').options).to eq(ssh_target_option_defaults.merge(host_key_check: true))
      end

      it 'should include values from parents' do
        expect(get_target(inventory, 'node4').port).to eq('2222')
      end

      it 'should use values from the first group' do
        expect(get_target(inventory, 'node6').options).to eq(ssh_target_option_defaults.merge(host_key_check: true))
      end

      it 'should prefer values from a node over an earlier group' do
        expect(get_target(inventory, 'node6').user).to eq('someone')
      end

      it 'should use values from matching groups' do
        expect(get_target(inventory, 'ssh://node8').port).to eq('2223')
      end

      it 'should only return config for exact matches' do
        expect(inventory.get_targets('node8')).to eq(targets(['node8']))
      end
    end

    context 'with nodes at the top level' do
      let(:data) {
        {
          'name' => 'group1',
          'nodes' => [
            'node1',
            { 'name' =>  'node2' },
            { 'name' =>  'node3',
              'config' => {
                'ssh' => {
                  'data' => true,
                  'port' => '2224'
                }
              } }
          ]
        }
      }
      let(:inventory) { Bolt::Inventory.new(data) }

      it 'should initialize' do
        expect(inventory).to be
      end

      it 'should return {} for a string node' do
        expect(get_target(inventory, 'node1').options).to eq(ssh_target_option_defaults)
      end

      it 'should return {} for a hash node with no config' do
        expect(get_target(inventory, 'node2').options).to eq(ssh_target_option_defaults)
      end

      it 'should return config for the node' do
        target = get_target(inventory, 'node3')
        expect(target.options).to eq(ssh_target_option_defaults)
        expect(target.port).to eq('2224')
      end

      it 'should return the raw target for an unknown node' do
        expect(inventory.get_targets('node5')).to eq(targets(['node5']))
      end
    end

    context 'with simple data in the group' do
      let(:data) {
        {
          'nodes' => [
            'node1',
            { 'name' =>  'node2' },
            { 'name' =>  'node3',
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
        } }
      let(:inventory) { Bolt::Inventory.new(data) }

      it 'should return group config for string nodes' do
        target = get_target(inventory, 'node1')
        expect(target.options).to eq(ssh_target_option_defaults.merge(host_key_check: false))
        expect(target.user).to eq('you')
      end

      it 'should return group config for array nodes' do
        target = get_target(inventory, 'node2')
        expect(target.options).to eq(ssh_target_option_defaults.merge(host_key_check: false))
        expect(target.user).to eq('you')
      end

      it 'should merge config for from nodes' do
        target = get_target(inventory, 'node3')
        expect(target.options).to eq(ssh_target_option_defaults.merge(host_key_check: false))
        expect(target.user).to eq('me')
      end
    end

    context 'with config errors in data' do
      let(:inventory) { Bolt::Inventory.new(data) }

      context 'host-key-check' do
        let(:data) {
          {
            'nodes' => ['node'],
            'config' => { 'ssh' => { 'host-key-check' => 'false' } }
          }
        }

        it 'fails validation' do
          expect { inventory.get_targets('node') }.to raise_error(Bolt::CLIError)
        end
      end

      context 'connect-timeout' do
        let(:data) {
          {
            'nodes' => ['node'],
            'config' => { 'winrm' => { 'connect-timeout' => '10' } }
          }
        }

        it 'fails validation' do
          expect { inventory.get_targets('node') }.to raise_error(Bolt::CLIError)
        end
      end

      context 'ssl' do
        let(:data) {
          {
            'nodes' => ['node'],
            'config' => { 'winrm' => { 'ssl' => 'true' } }
          }
        }

        it 'fails validation' do
          expect { inventory.get_targets('node') }.to raise_error(Bolt::CLIError)
        end
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
          'host-key-check' => false,
          'connect-timeout' => transport.size,
          'tmpdir' => '/' + transport,
          'run-as' => 'root',
          'sudo-password' => 'nothing',
          'extensions' => '.py',
          'service-url' => 'https://master',
          'cacert' => transport + '.pem',
          'token-file' => 'token',
          'task-environment' => 'prod',
          'local-validation' => true
        }
      end

      let(:data) {
        {
          'nodes' => ['ssh://node', 'winrm://node', 'pcp://node', 'node'],
          'config' => {
            'transport' => 'winrm',
            'modulepath' => 'nonsense',
            'ssh' => common_data('ssh'),
            'winrm' => common_data('winrm'),
            'pcp' => common_data('pcp')
          }
        }
      }
      let(:conf) { Bolt::Config.new }
      let(:inventory) { Bolt::Inventory.new(data, conf) }

      it 'should not modify existing config' do
        get_target(inventory, 'ssh://node')
        expect(conf[:modulepath]).to eq([])
        expect(conf[:transport]).to eq('ssh')
        expect(conf[:transports][:ssh][:host_key_check]).to be true
        expect(conf[:transports][:winrm][:ssl]).to be true
      end

      it 'uses the configured transport' do
        target = get_target(inventory, 'node')
        expect(target.protocol).to eq('winrm')
      end

      it 'only uses configured options for ssh' do
        target = get_target(inventory, 'ssh://node')
        expect(target.protocol).to eq('ssh')
        expect(target.user).to eq('messh')
        expect(target.password).to eq('youssh')
        expect(target.port).to eq('12345ssh')
        expect(target.options).to eq(
          connect_timeout: 3,
          tty: false,
          host_key_check: false,
          key: "anything",
          tmpdir: "/ssh",
          run_as: "root",
          sudo_password: "nothing"
        )
      end

      it 'only uses configured options for winrm' do
        target = get_target(inventory, 'winrm://node')
        expect(target.protocol).to eq('winrm')
        expect(target.user).to eq('mewinrm')
        expect(target.password).to eq('youwinrm')
        expect(target.port).to eq('12345winrm')
        expect(target.options).to eq(
          connect_timeout: 5,
          tty: false,
          ssl: false,
          tmpdir: "/winrm",
          cacert: "winrm.pem",
          extensions: [".py"]
        )
      end

      it 'only uses configured options for pcp' do
        target = get_target(inventory, 'pcp://node')
        expect(target.protocol).to eq('pcp')
        expect(target.user).to be nil
        expect(target.password).to be nil
        expect(target.port).to be nil
        expect(target.options).to eq(
          connect_timeout: 10,
          :"task-environment" => "prod",
          tty: false,
          :"service-url" => "https://master",
          cacert: "pcp.pem",
          :"token-file" => "token",
          :"local-validation" => true
        )
      end
    end
  end
end
