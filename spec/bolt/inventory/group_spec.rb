require 'spec_helper'
require 'bolt/inventory'
require 'bolt/inventory/group'

# This is largely internal and probably shouldn't be tested
describe Bolt::Inventory::Group do
  let(:data) { {} }
  let(:group) { Bolt::Inventory::Group.new(data) }
  let(:node1_ssh) { group.data_for('node1')['config']['ssh']['user'] }

  it 'returns nil' do
    expect(group.data_for('node1')).to be_nil
  end

  context 'with nodes at the top level' do
    let(:data) {
      {
        'name' => 'group1',
        'nodes' => [
          'node1',
          { 'name' => 'node2' },
          { 'name' => 'node3',
            'config' => {
              'ssh' => true
            } }
        ]
      }
    }

    it 'should initialize' do
      expect(group).to be
    end

    it 'should have three nodes' do
      expect(group.nodes.length).to eq(3)
    end

    it 'should return empty data' do
      expect(group.node_data('node1')).to eq('config' => {}, 'groups' => [])
    end

    it 'should include node1' do
      expect(group.node_names).to include('node1')
    end

    it 'should return a hash for a string node' do
      expect(group.data_for('node1')).to be
    end

    it 'should return a hash for hash defined nodes' do
      expect(group.data_for('node2')).to be
    end

    it 'should return nil for an unknown node' do
      expect(group.data_for('node5')).to be_nil
    end
  end

  context 'with data at all levels' do
    let(:data) do
      {
        'nodes' => [{
          'name' => 'node1',
          'config' => { 'ssh' => { 'user' => 'parent_node' } }
        }],
        'config' => { 'ssh' => { 'user' => 'parent_group' } },
        'groups' => [
          { 'name' => 'group1',
            'nodes' => [{
              'name' => 'node1',
              'config' => { 'ssh' => { 'user' => 'child_node' } }
            }],
            'config' => { 'ssh' => { 'user' => 'child_group' } } }
        ]
      }
    end

    it 'uses the childs node defintion' do
      expect(group.data_for('node1')['config']['ssh']['user']).to eq('child_node')
    end
  end

  context 'with node data in parent and group in the child' do
    let(:data) do
      {
        'nodes' => [{
          'name' => 'node1',
          'config' => { 'ssh' => { 'user' => 'parent_node' } }
        }],
        'config' => { 'ssh' => { 'user' => 'parent_group' } },
        'groups' => [{
          'name' => 'group1',
          'nodes' => [{
            'name' => 'node1'
          }],
          'config' => { 'ssh' => { 'user' => 'child_group' } }
        }]
      }
    end

    it 'uses the parents node defintion' do
      expect(group.data_for('node1')['config']['ssh']['user']).to eq('parent_node')
    end
  end

  context 'with group data at all levels' do
    let(:data) do
      {
        'nodes' => [{
          'name' => 'node1'
        }],
        'config' => { 'ssh' => { 'user' => 'parent_group' } },
        'groups' => [{
          'name' => 'group1',
          'nodes' => [{
            'name' => 'node1'
          }],
          'config' => { 'ssh' => { 'user' => 'child_group' } }
        }]
      }
    end

    it 'uses the childs group defintion' do
      expect(group.data_for('node1')['config']['ssh']['user']).to eq('child_group')
    end
  end

  context 'with two children which both set node' do
    let(:data) do
      {
        'nodes' => [{
          'name' => 'node1',
          'config' => { 'ssh' => { 'user' => 'parent_node' } }
        }],
        'config' => { 'ssh' => { 'user' => 'parent_group' } },
        'groups' => [
          {
            'name' => 'group1',
            'nodes' => [{
              'name' => 'node1',
              'config' => { 'ssh' => { 'user' => 'child1_node' } }
            }],
            'config' => { 'ssh' => { 'user' => 'child1_group' } }
          },
          {
            'name' => 'group2',
            'nodes' => [{
              'name' => 'node1',
              'config' => { 'ssh' => { 'user' => 'child2_node' } }
            }],
            'config' => { 'ssh' => { 'user' => 'child2_group' } }
          }

        ]
      }
    end

    it 'uses the first childs node defintion' do
      expect(node1_ssh).to eq('child1_node')
    end
  end

  context 'with two children where the second sets node' do
    let(:data) do
      {
        'nodes' => [{
          'name' => 'node1',
          'config' => { 'ssh' => { 'user' => 'parent_node' } }
        }],
        'config' => { 'ssh' => { 'user' => 'parent_group' } },
        'groups' => [
          {
            'name' => 'group1',
            'nodes' => [{
              'name' => 'node1',
              'config' => { 'ssh' => {} }
            }],
            'config' => { 'ssh' => { 'user' => 'child1_group' } }
          },
          {
            'name' => 'group2',
            'nodes' => [{
              'name' => 'node1',
              'config' => { 'ssh' => { 'user' => 'child2_node' } }
            }],
            'config' => { 'ssh' => { 'user' => 'child2_group' } }
          }

        ]
      }
    end

    it 'uses the first childs node defintion' do
      expect(node1_ssh).to eq('child2_node')
    end
  end

  context 'with two children where both set group' do
    let(:data) do
      {
        'nodes' => [{
          'name' => 'node1',
          'config' => { 'ssh' => {} }
        }],
        'config' => { 'ssh' => { 'user' => 'parent_group' } },
        'groups' => [
          {
            'name' => 'group1',
            'nodes' => [{
              'name' => 'node1',
              'config' => { 'ssh' => {} }
            }],
            'config' => { 'ssh' => { 'user' => 'child1_group' } }
          },
          {
            'name' => 'group2',
            'nodes' => [{
              'name' => 'node1',
              'config' => { 'ssh' => {} }
            }],
            'config' => { 'ssh' => { 'user' => 'child2_group' } }
          }

        ]
      }
    end

    it 'uses the first childs group defintion' do
      expect(node1_ssh).to eq('child1_group')
    end
  end

  context 'with two children where the second sets group' do
    let(:data) do
      {
        'nodes' => [{
          'name' => 'node1',
          'config' => { 'ssh' => {} }
        }],
        'config' => { 'ssh' => { 'user' => 'parent_group' } },
        'groups' => [
          {
            'name' => 'group1',
            'nodes' => [{
              'name' => 'node1',
              'config' => { 'ssh' => {} }
            }],
            'config' => { 'ssh' => {} }
          },
          {
            'name' => 'group2',
            'nodes' => [{
              'name' => 'node1',
              'config' => { 'ssh' => {} }
            }],
            'config' => { 'ssh' => { 'user' => 'child2_group' } }
          }

        ]
      }
    end

    it 'uses the second childs group defintion' do
      expect(node1_ssh).to eq('child2_group')
    end
  end
end
