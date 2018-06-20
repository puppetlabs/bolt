# frozen_string_literal: true

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
      expect(group.node_data('node1')).to eq('config' => {},
                                             'vars' => {},
                                             'facts' => {},
                                             'features' => [],
                                             'groups' => [])
    end

    it 'should find three nodes' do
      expect(group.node_names.to_a).to eq(%w[node1 node2 node3])
    end

    it 'should collect one group' do
      groups = group.collect_groups
      expect(groups.size).to eq(1)
      expect(groups['group1']).to eq(group)
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
        'name' => 'group0',
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

    it 'uses the childs node definition' do
      expect(group.data_for('node1')['config']['ssh']['user']).to eq('child_node')
    end

    it 'should find one node' do
      expect(group.node_names.to_a).to eq(%w[node1])
    end

    it 'should collect 2 groups' do
      groups = group.collect_groups
      expect(groups.size).to eq(2)
      expect(groups['group0']).to eq(group)
      expect(groups['group1'].name).to eq('group1')
    end

    it 'should find one node in the subgroup' do
      groups = group.collect_groups
      expect(groups['group1'].node_names.to_a).to eq(%w[node1])
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

    it 'uses the parents node definition' do
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

    it 'uses the childs group definition' do
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

    it 'uses the first childs node definition' do
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

    it 'uses the first childs node definition' do
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

    it 'uses the first childs group definition' do
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

    it 'uses the second childs group definition' do
      expect(node1_ssh).to eq('child2_group')
    end
  end

  context 'with IP-based nodes in multiple group levels' do
    let(:data) do
      {
        'name' => 'group0',
        'nodes' => [{ 'name' => '127.0.0.1' }],
        'groups' => [
          {
            'name' => 'group1',
            'nodes' => [{ 'name' => '2001:db8:0:1:8080' }]
          }
        ]
      }
    end

    it 'should find two nodes' do
      expect(group.node_names.to_a).to eq(%w[127.0.0.1 2001:db8:0:1:8080])
    end

    it 'should collect 2 groups' do
      groups = group.collect_groups
      expect(groups.size).to eq(2)
      expect(groups['group0']).to eq(group)
      expect(groups['group1'].name).to eq('group1')
    end

    it 'should find one node in the subgroup' do
      groups = group.collect_groups
      expect(groups['group1'].node_names.to_a).to eq(%w[2001:db8:0:1:8080])
    end
  end

  context 'with full node URIs' do
    let(:data) do
      {
        'name' => 'group0',
        'nodes' => [
          { 'name' => 'ssh://127.0.0.1:22' },
          { 'name' => '127.0.0.1' }
        ]
      }
    end

    it 'should find two distinct nodes' do
      expect(group.node_names.to_a).to eq(%w[ssh://127.0.0.1:22 127.0.0.1])
    end
  end

  context 'with a duplicate node' do
    let(:data) do
      {
        'name' => 'group1',
        'nodes' => [
          { 'name' => 'node1',
            'val' => 'a' },
          { 'name' => 'node1',
            'val' => 'b' }
        ]
      }
    end

    it 'uses the first value' do
      expect(group.nodes['node1']['val']).to eq('a')
    end
  end

  context 'where a node uses an invalid name' do
    let(:data) do
      {
        'name' => 'group1',
        'nodes' => [{ 'name' => 'foo:a/b@neptune"' }]
      }
    end

    it 'raises an error' do
      expect { group.validate }.to raise_error(Bolt::Inventory::ValidationError, /Invalid node name/)
    end
  end

  context 'where a group name conflicts with a prior node name' do
    let(:data) do
      {
        'name' => 'group1',
        'nodes' => [{ 'name' => 'foo1' }],
        'groups' => [{ 'name' => 'foo1' }]
      }
    end

    it 'raises an error' do
      expect { group.validate }.to raise_error(Bolt::Inventory::ValidationError, /conflicts with node/)
    end
  end

  context 'where a group name conflicts with a child node name' do
    let(:data) do
      {
        'name' => 'group1',
        'groups' => [
          {
            'name' => 'foo1',
            'nodes' => [{ 'name' => 'foo1' }]
          }
        ]
      }
    end

    it 'raises an error' do
      expect { group.validate }.to raise_error(Bolt::Inventory::ValidationError, /conflicts with node/)
    end
  end

  context 'where a group name conflicts with a child node of another group' do
    let(:data) do
      {
        'name' => 'group1',
        'groups' => [
          { 'name' => 'foo1' },
          {
            'name' => 'foo2',
            'nodes' => [{ 'name' => 'foo1' }]
          }
        ]
      }
    end

    it 'raises an error' do
      expect { group.validate }.to raise_error(Bolt::Inventory::ValidationError, /conflicts with node/)
    end
  end

  context 'with nested groups' do
    context 'when one group contains a child group' do
      let(:data) do
        {
          'name' => 'root',
          'groups' => [{
            'name' => 'parent',
            'groups' => [{
              'name' => 'child',
              'nodes' => [{ 'name' => 'node1' }],
              'vars' => { 'foo' => 'bar' },
              'features' => ['a']
            }],
            'vars' => { 'foo' => 'qux', 'a' => 'b' },
            'features' => ['b']
          }]
        }
      end

      before :each do
        group.validate
      end

      it 'returns the node as a member of the parent group' do
        expect(group.node_names).to include('node1')
      end

      it 'overrides parent group data with child group data' do
        expect(group.data_for('node1')['vars']).to eq('foo' => 'bar', 'a' => 'b')
      end

      it 'combines parent group features with child group features' do
        expect(group.data_for('node1')['features']).to match_array(%w[a b])
      end

      it 'returns the whole ancestry as the list of groups for the node' do
        expect(group.data_for('node1')['groups']).to eq(%w[child parent root])
      end
    end

    context 'when one group contains two child groups' do
      let(:data) do
        {
          'name' => 'root',
          'groups' => [{
            'name' => 'parent',
            'groups' => [{
              'name' => 'child1',
              'nodes' => [{ 'name' => 'node1' }],
              'vars' => { 'foo' => 'bar' }
            }, {
              'name' => 'child2',
              'nodes' => [{ 'name' => 'node2' }],
              'vars' => { 'foo' => 'baz' }
            }],
            'vars' => { 'foo' => 'qux', 'a' => 'b' }
          }]
        }
      end

      before :each do
        group.validate
      end

      it 'returns all child nodes as members of the parent group' do
        expect(group.node_names.to_a.sort).to eq(%w[node1 node2])
      end

      it 'overrides parent group data with child group data' do
        expect(group.data_for('node1')['vars']).to eq('foo' => 'bar', 'a' => 'b')
        expect(group.data_for('node2')['vars']).to eq('foo' => 'baz', 'a' => 'b')
      end

      it 'returns the whole ancestry as the list of groups for the node' do
        expect(group.data_for('node1')['groups']).to eq(%w[child1 parent root])
        expect(group.data_for('node2')['groups']).to eq(%w[child2 parent root])
      end
    end
  end

  context 'when a group is duplicated in two parent groups' do
    let(:data) do
      {
        'name' => 'root',
        'groups' => [{
          'name' => 'parent',
          'groups' => [{
            'name' => 'child1',
            'nodes' => [{ 'name' => 'node1' }],
            'vars' => { 'foo' => 'bar' }
          }, {
            'name' => 'child1',
            'nodes' => [{ 'name' => 'node2' }],
            'vars' => { 'foo' => 'baz' }
          }],
          'vars' => { 'foo' => 'qux', 'a' => 'b' }
        }]
      }
    end

    it 'fails because the group is duplicated' do
      expect { group.validate }.to raise_error(Bolt::Inventory::ValidationError, /Tried to redefine group/)
    end
  end

  context 'when a node is contained at multiple levels of the group hierarchy' do
    let(:data) do
      {
        'name' => 'root',
        'groups' => [{
          'name' => 'parent1',
          'nodes' => [{ 'name' => 'node1' }],
          'vars' => { 'foo' => 'bar' },
          'features' => ['a']
        }, {
          'name' => 'parent2',
          'groups' => [{
            'name' => 'child1',
            'nodes' => [{ 'name' => 'node1' }],
            'vars' => { 'foo' => 'baz', 'a' => 'b' },
            'features' => ['b']
          }]
        }]
      }
    end

    before :each do
      group.validate
    end

    it 'uses values from the first branch encountered, picking the most specific subgroup' do
      expect(group.data_for('node1')['groups']).to eq(%w[parent1 child1 parent2 root])
      expect(group.data_for('node1')['vars']).to eq('foo' => 'bar', 'a' => 'b')
      expect(group.data_for('node1')['features']).to match_array(%w[a b])
    end
  end
end
