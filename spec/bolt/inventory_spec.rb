require 'spec_helper'
require 'bolt_spec/config'
require 'bolt/inventory'

describe Bolt::Inventory do
  include BoltSpec::Config

  def targets(names)
    names.map { |n| Bolt::Target.new(n) }
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
          'insecure' => 'true',
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
              'insecure' => false
            }
          } },
        { 'name' => 'group2',
          'nodes' => [
            { 'name' => 'node6',
              'config' => {
                'ssh' => { 'user' => 'someone' }
              } },
            'node7', 'node8'
          ],
          'config' => { 'ssh' => {
            'insecure' => 'maybe'
          } } }
      ]
    }
  }

  describe :config_for do
    context 'with nodes at the top level' do
      let(:data) {
        {
          'name' => 'group1',
          'nodes' => [
            'node1',
            { 'name' =>  'node2' },
            { 'name' =>  'node3',
              'config' => {
                'ssh' => true
              } }
          ]
        }
      }
      let(:inventory) { Bolt::Inventory.new(data) }

      it 'should initialize' do
        expect(inventory).to be
      end

      it 'should return {} for a string node' do
        expect(inventory.config_for('node1')).to eq({})
      end

      it 'should return {} for a hash node with no config' do
        expect(inventory.config_for('node2')).to eq({})
      end

      it 'should return config for the node' do
        expect(inventory.config_for('node3')).to eq(ssh: true)
      end

      it 'should return nil for an unknown node' do
        expect(inventory.config_for('node5')).to be_nil
      end
    end

    context 'with data in the group' do
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
              'insecure' => 'true'
            }
          }
        } }
      let(:inventory) { Bolt::Inventory.new(data) }

      it 'should return group config for string nodes' do
        expect(inventory.config_for('node1')).to eq(ssh: {
                                                      user: 'you',
                                                      insecure: 'true'
                                                    })
      end

      it 'should return group config for array nodes' do
        expect(inventory.config_for('node2')).to eq(ssh: {
                                                      user: 'you',
                                                      insecure: 'true'
                                                    })
      end
      it 'should merge config for from nodes' do
        expect(inventory.config_for('node3')).to eq(ssh: {
                                                      user: 'me',
                                                      insecure: 'true'
                                                    })
      end
    end

    context 'with data in the group' do
      let(:inventory) { Bolt::Inventory.new(data) }

      it 'should use value from lowest node definition' do
        expect(inventory.config_for('node4')[:ssh][:user]).to eq('me')
      end

      it 'should use values from the lowest group' do
        expect(inventory.config_for('node4')[:ssh][:insecure]).to eq(false)
      end

      it 'should include values from parents' do
        expect(inventory.config_for('node4')[:ssh][:port]).to eq('2222')
      end

      it 'should use values from the lowest group' do
        expect(inventory.config_for('node4')[:ssh][:port]).to eq('2222')
      end

      it 'should use values from the first group' do
        expect(inventory.config_for('node6')[:ssh][:insecure]).to eq(false)
      end

      it 'should prefer values from a node over an earlier group' do
        expect(inventory.config_for('node6')[:ssh][:user]).to eq('someone')
      end

      it 'should use values from matching groups' do
        expect(inventory.config_for('node8')[:ssh][:insecure]).to eq('maybe')
      end
    end
  end

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
      expect(targets).to eq(targets(%w[node6 node7 node8]))
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
        targets = inventory.get_targets('group1,a')
        expect(targets).to eq(targets(%w[node4 node5 node6 node7 a]))
      end
    end
  end
end
