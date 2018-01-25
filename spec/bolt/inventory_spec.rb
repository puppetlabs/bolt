require 'spec_helper'
require 'bolt_spec/config'
require 'bolt/inventory'

describe Bolt::Inventory do
  include BoltSpec::Config

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
        } }
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

    it 'accepts empty inventory' do
      data = {
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
      expect(Bolt::Inventory.new(data).validate).to be_nil
    end

    it 'fails with unamed groups' do
      data = { 'groups' => [{}] }
      expect { Bolt::Inventory.new(data).validate }.to raise_error(Bolt::Inventory::ValidationError)
    end

    it 'fails with duplicate groups' do
      data = { 'groups' => [{ 'name' => 'group1' }, { 'name' => 'group1' }] }
      expect { Bolt::Inventory.new(data).validate }.to raise_error(Bolt::Inventory::ValidationError)
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

    context 'with inventory' do
    end
  end
end
