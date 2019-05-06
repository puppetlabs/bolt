# frozen_string_literal: true

require 'spec_helper'
require 'bolt/inventory'
require 'bolt/inventory/group'

# This is largely internal and probably shouldn't be tested
describe Bolt::Inventory::Group2 do
  let(:data) { { 'name' => 'all' } }
  let(:group) {
    # Inventory always resolves unknown labels to names or aliases from the top-down when constructed,
    # passing the collection of all aliases in it. Do that manually here to ensure plain target strings
    # are included as targets.
    g = Bolt::Inventory::Group2.new(data)
    g.resolve_aliases(g.target_aliases, g.target_names)
    g
  }
  let(:target1_ssh) { group.data_for('target1')['config']['ssh']['user'] }

  it 'returns nil' do
    expect(group.data_for('target1')).to be_nil
  end

  context 'with targets at the top level' do
    let(:data) {
      {
        'name' => 'group1',
        'targets' => [
          'target1',
          { 'name' => 'target2' },
          { 'name' => 'target3',
            'config' => {
              'ssh' => true
            } }
        ]
      }
    }

    it 'should initialize' do
      expect(group).to be
    end

    it 'should have three targets' do
      expect(group.targets.length).to eq(3)
    end

    it 'should return empty data' do
      expect(group.target_data('target1')).to eq('config' => {},
                                                 'vars' => {},
                                                 'name' => nil,
                                                 'uri' => 'target1',
                                                 'facts' => {},
                                                 'features' => [],
                                                 'groups' => [])
    end

    it 'should find three targets' do
      expect(group.target_names.to_a.sort).to eq(%w[target1 target2 target3])
    end

    it 'should collect one group' do
      groups = group.collect_groups
      expect(groups.size).to eq(1)
      expect(groups['group1']).to eq(group)
    end

    it 'should return a hash for a string target' do
      expect(group.data_for('target1')).to be
    end

    it 'should return a hash for hash defined targets' do
      expect(group.data_for('target2')).to be
    end

    it 'should return nil for an unknown target' do
      expect(group.data_for('target5')).to be_nil
    end
  end

  context 'with data at all levels' do
    let(:data) do
      {
        'name' => 'group0',
        'targets' => [{
          'name' => 'target1',
          'config' => { 'ssh' => { 'user' => 'parent_target' } }
        }],
        'config' => { 'ssh' => { 'user' => 'parent_group' } },
        'groups' => [
          { 'name' => 'group1',
            'targets' => [{
              'name' => 'target1',
              'config' => { 'ssh' => { 'user' => 'child_target' } }
            }],
            'config' => { 'ssh' => { 'user' => 'child_group' } } }
        ]
      }
    end

    it 'uses the childs target definition' do
      expect(group.data_for('target1')['config']['ssh']['user']).to eq('child_target')
    end

    it 'should find one target' do
      expect(group.target_names.to_a).to eq(%w[target1])
    end

    it 'should collect 2 groups' do
      groups = group.collect_groups
      expect(groups.size).to eq(2)
      expect(groups['group0']).to eq(group)
      expect(groups['group1'].name).to eq('group1')
    end

    it 'should find one target in the subgroup' do
      groups = group.collect_groups
      expect(groups['group1'].target_names.to_a).to eq(%w[target1])
    end
  end

  context 'with target data in parent and group in the child' do
    let(:data) do
      {
        'name' => 'all',
        'targets' => [{
          'name' => 'target1',
          'config' => { 'ssh' => { 'user' => 'parent_target' } }
        }],
        'config' => { 'ssh' => { 'user' => 'parent_group' } },
        'groups' => [{
          'name' => 'group1',
          'targets' => [{
            'name' => 'target1'
          }],
          'config' => { 'ssh' => { 'user' => 'child_group' } }
        }]
      }
    end

    it 'uses the parents target definition' do
      expect(group.data_for('target1')['config']['ssh']['user']).to eq('parent_target')
    end
  end

  context 'with group data at all levels' do
    let(:data) do
      {
        'name' => 'all',
        'targets' => [{
          'name' => 'target1'
        }],
        'config' => { 'ssh' => { 'user' => 'parent_group' } },
        'groups' => [{
          'name' => 'group1',
          'targets' => [{
            'name' => 'target1'
          }],
          'config' => { 'ssh' => { 'user' => 'child_group' } }
        }]
      }
    end

    it 'uses the childs group definition' do
      expect(group.data_for('target1')['config']['ssh']['user']).to eq('child_group')
    end
  end

  context 'with two children which both set target' do
    let(:data) do
      {
        'name' => 'all',
        'targets' => [{
          'name' => 'target1',
          'config' => { 'ssh' => { 'user' => 'parent_target' } }
        }],
        'config' => { 'ssh' => { 'user' => 'parent_group' } },
        'groups' => [
          {
            'name' => 'group1',
            'targets' => [{
              'name' => 'target1',
              'config' => { 'ssh' => { 'user' => 'child1_target' } }
            }],
            'config' => { 'ssh' => { 'user' => 'child1_group' } }
          },
          {
            'name' => 'group2',
            'targets' => [{
              'name' => 'target1',
              'config' => { 'ssh' => { 'user' => 'child2_target' } }
            }],
            'config' => { 'ssh' => { 'user' => 'child2_group' } }
          }

        ]
      }
    end

    it 'uses the first childs target definition' do
      expect(target1_ssh).to eq('child1_target')
    end
  end

  context 'with two children where the second sets target' do
    let(:data) do
      {
        'name' => 'all',
        'targets' => [{
          'name' => 'target1',
          'config' => { 'ssh' => { 'user' => 'parent_target' } }
        }],
        'config' => { 'ssh' => { 'user' => 'parent_group' } },
        'groups' => [
          {
            'name' => 'group1',
            'targets' => [{
              'name' => 'target1',
              'config' => { 'ssh' => {} }
            }],
            'config' => { 'ssh' => { 'user' => 'child1_group' } }
          },
          {
            'name' => 'group2',
            'targets' => [{
              'name' => 'target1',
              'config' => { 'ssh' => { 'user' => 'child2_target' } }
            }],
            'config' => { 'ssh' => { 'user' => 'child2_group' } }
          }

        ]
      }
    end

    it 'uses the first childs target definition' do
      expect(target1_ssh).to eq('child2_target')
    end
  end

  context 'with two children where both set group' do
    let(:data) do
      {
        'name' => 'all',
        'targets' => [{
          'name' => 'target1',
          'config' => { 'ssh' => {} }
        }],
        'config' => { 'ssh' => { 'user' => 'parent_group' } },
        'groups' => [
          {
            'name' => 'group1',
            'targets' => [{
              'name' => 'target1',
              'config' => { 'ssh' => {} }
            }],
            'config' => { 'ssh' => { 'user' => 'child1_group' } }
          },
          {
            'name' => 'group2',
            'targets' => [{
              'name' => 'target1',
              'config' => { 'ssh' => {} }
            }],
            'config' => { 'ssh' => { 'user' => 'child2_group' } }
          }

        ]
      }
    end

    it 'uses the first childs group definition' do
      expect(target1_ssh).to eq('child1_group')
    end
  end

  context 'with two children where the second sets group' do
    let(:data) do
      {
        'name' => 'all',
        'targets' => [{
          'name' => 'target1',
          'config' => { 'ssh' => {} }
        }],
        'config' => { 'ssh' => { 'user' => 'parent_group' } },
        'groups' => [
          {
            'name' => 'group1',
            'targets' => [{
              'name' => 'target1',
              'config' => { 'ssh' => {} }
            }],
            'config' => { 'ssh' => {} }
          },
          {
            'name' => 'group2',
            'targets' => [{
              'name' => 'target1',
              'config' => { 'ssh' => {} }
            }],
            'config' => { 'ssh' => { 'user' => 'child2_group' } }
          }

        ]
      }
    end

    it 'uses the second childs group definition' do
      expect(target1_ssh).to eq('child2_group')
    end
  end

  context 'with IP-based targets in multiple group levels' do
    let(:data) do
      {
        'name' => 'group0',
        'targets' => [{ 'name' => '127.0.0.1' }],
        'groups' => [
          {
            'name' => 'group1',
            'targets' => [{ 'name' => '2001:db8:0:1:8080' }]
          }
        ]
      }
    end

    it 'should find two targets' do
      expect(group.target_names.to_a).to eq(%w[127.0.0.1 2001:db8:0:1:8080])
    end

    it 'should collect 2 groups' do
      groups = group.collect_groups
      expect(groups.size).to eq(2)
      expect(groups['group0']).to eq(group)
      expect(groups['group1'].name).to eq('group1')
    end

    it 'should find one target in the subgroup' do
      groups = group.collect_groups
      expect(groups['group1'].target_names.to_a).to eq(%w[2001:db8:0:1:8080])
    end
  end

  context 'with full target URIs' do
    let(:data) do
      {
        'name' => 'group0',
        'targets' => [
          { 'name' => 'ssh://127.0.0.1:22' },
          { 'name' => '127.0.0.1' }
        ]
      }
    end

    it 'should find two distinct targets' do
      expect(group.target_names.to_a).to eq(%w[ssh://127.0.0.1:22 127.0.0.1])
    end
  end

  context 'with a duplicate target' do
    let(:data) do
      {
        'name' => 'group1',
        'targets' => [
          { 'name' => 'target1',
            'val' => 'a' },
          { 'name' => 'target1',
            'val' => 'b' }
        ]
      }
    end

    it 'uses the first value' do
      expect(group.targets['target1']['val']).to eq('a')
    end
  end

  context 'where a target uses an invalid name' do
    let(:data) do
      {
        'name' => 'group1',
        'targets' => [{ 'name' => 'foo:a/b@neptune"' }]
      }
    end

    it 'raises an error' do
      expect { group.validate }.to raise_error(Bolt::Inventory::ValidationError, /Invalid target name/)
    end
  end

  context 'where a group name conflicts with a prior target name' do
    let(:data) do
      {
        'name' => 'group1',
        'targets' => [{ 'name' => 'foo1' }],
        'groups' => [{ 'name' => 'foo1' }]
      }
    end

    it 'raises an error' do
      expect { group.validate }.to raise_error(Bolt::Inventory::ValidationError, /conflicts with target/)
    end
  end

  context 'where a group name conflicts with a child target name' do
    let(:data) do
      {
        'name' => 'group1',
        'groups' => [
          {
            'name' => 'foo1',
            'targets' => [{ 'name' => 'foo1' }]
          }
        ]
      }
    end

    it 'raises an error' do
      expect { group.validate }.to raise_error(Bolt::Inventory::ValidationError, /conflicts with target/)
    end
  end

  context 'where a group name conflicts with a child target of another group' do
    let(:data) do
      {
        'name' => 'group1',
        'groups' => [
          { 'name' => 'foo1' },
          {
            'name' => 'foo2',
            'targets' => [{ 'name' => 'foo1' }]
          }
        ]
      }
    end

    it 'raises an error' do
      expect { group.validate }.to raise_error(Bolt::Inventory::ValidationError, /conflicts with target/)
    end
  end

  context 'where a config value is not a hash' do
    let(:data) do
      {
        'name' => 'group1',
        'groups' => [
          {
            'name' => 'foo1',
            'targets' => [{ 'name' => 'foo1', 'config' => 'foo' }]
          }
        ]
      }
    end

    it 'raises an error' do
      expect { group.validate }.to raise_error(Bolt::Inventory::ValidationError, /Invalid configuration for target/)
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
              'targets' => [{ 'name' => 'target1' }],
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

      it 'returns the target as a member of the parent group' do
        expect(group.target_names).to include('target1')
      end

      it 'overrides parent group data with child group data' do
        expect(group.data_for('target1')['vars']).to eq('foo' => 'bar', 'a' => 'b')
      end

      it 'combines parent group features with child group features' do
        expect(group.data_for('target1')['features']).to match_array(%w[a b])
      end

      it 'returns the whole ancestry as the list of groups for the target' do
        expect(group.data_for('target1')['groups']).to eq(%w[child parent root])
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
              'targets' => [{ 'name' => 'target1' }],
              'vars' => { 'foo' => 'bar' }
            }, {
              'name' => 'child2',
              'targets' => [{ 'name' => 'target2' }],
              'vars' => { 'foo' => 'baz' }
            }],
            'vars' => { 'foo' => 'qux', 'a' => 'b' }
          }]
        }
      end

      before :each do
        group.validate
      end

      it 'returns all child targets as members of the parent group' do
        expect(group.target_names.to_a.sort).to eq(%w[target1 target2])
      end

      it 'overrides parent group data with child group data' do
        expect(group.data_for('target1')['vars']).to eq('foo' => 'bar', 'a' => 'b')
        expect(group.data_for('target2')['vars']).to eq('foo' => 'baz', 'a' => 'b')
      end

      it 'returns the whole ancestry as the list of groups for the target' do
        expect(group.data_for('target1')['groups']).to eq(%w[child1 parent root])
        expect(group.data_for('target2')['groups']).to eq(%w[child2 parent root])
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
            'targets' => [{ 'name' => 'target1' }],
            'vars' => { 'foo' => 'bar' }
          }, {
            'name' => 'child1',
            'targets' => [{ 'name' => 'target2' }],
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

  context 'when a target is contained at multiple levels of the group hierarchy' do
    let(:data) do
      {
        'name' => 'root',
        'groups' => [{
          'name' => 'parent1',
          'targets' => [{ 'name' => 'target1' }],
          'vars' => { 'foo' => 'bar' },
          'features' => ['a']
        }, {
          'name' => 'parent2',
          'groups' => [{
            'name' => 'child1',
            'targets' => [{ 'name' => 'target1' }],
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
      expect(group.data_for('target1')['groups']).to eq(%w[parent1 child1 parent2 root])
      expect(group.data_for('target1')['vars']).to eq('foo' => 'bar', 'a' => 'b')
      expect(group.data_for('target1')['features']).to match_array(%w[a b])
    end
  end

  context 'when the input is structurally invalid' do
    let(:data) do
      {
        'name' => 'root',
        'targets' => ['foo.example.com', 'bar.example.com'],
        'groups' => [{ 'name' => 'foo_group' }],
        'vars' => { 'key' => 'value' },
        'facts' => { 'osfamily' => 'windows' },
        'features' => ['shell'],
        'config' => { 'transport' => 'ssh' }
      }
    end

    it 'fails if the targets list is not an array' do
      data['targets'] = 'foo.example.com,bar.example.com'
      expect { Bolt::Inventory::Group2.new(data) }.to raise_error(/Expected targets to be of type Array/)
    end

    it 'fails if a target in the list is not a string or hash' do
      data['targets'] = [['foo.example.com']]
      expect { Bolt::Inventory::Group2.new(data) }.to raise_error(/Node entry must be a String or Hash/)
    end

    it 'fails if the groups list is not an array' do
      data['groups'] = { 'name' => 'foo_group' }
      expect { Bolt::Inventory::Group2.new(data) }.to raise_error(/Expected groups to be of type Array/)
    end

    it 'fails if vars is not a hash' do
      data['vars'] = ['foo=bar']
      expect { Bolt::Inventory::Group2.new(data) }.to raise_error(/Expected vars to be of type Hash/)
    end

    it 'fails if facts is not a hash' do
      data['facts'] = ['foo=bar']
      expect { Bolt::Inventory::Group2.new(data) }.to raise_error(/Expected facts to be of type Hash/)
    end

    it 'fails if features is not an array' do
      data['features'] = 'shell'
      expect { Bolt::Inventory::Group2.new(data) }.to raise_error(/Expected features to be of type Array/)
    end

    it 'fails if config is not a hash' do
      data['config'] = 'transport=ssh'
      expect { Bolt::Inventory::Group2.new(data) }.to raise_error(/Expected config to be of type Hash/)
    end
  end

  describe 'with aliases' do
    context 'has an alias' do
      let(:data) do
        {
          'name' => 'root',
          'targets' => [
            { 'name' => 'target1', 'alias' => 'alias1' }
          ]
        }
      end

      it { expect(group.target_names.to_a).to eq(%w[target1]) }
      it { expect(group.target_aliases).to eq('alias1' => 'target1') }
    end

    context 'multiple aliases' do
      let(:data) do
        {
          'name' => 'root',
          'targets' => [
            { 'name' => 'target1', 'alias' => %w[alias1 alias2] }
          ],
          'groups' => [
            { 'name' => 'group1', 'targets' => [{ 'name' => 'target2', 'alias' => 'alias3' }] }
          ]
        }
      end

      it { expect(group.target_names.to_a).to eq(%w[target1 target2]) }
      it { expect(group.target_aliases).to eq('alias1' => 'target1', 'alias2' => 'target1', 'alias3' => 'target2') }
    end

    context 'redundant targets' do
      let(:data) do
        {
          'name' => 'root',
          'targets' => [
            'target1',
            { 'name' => 'target1', 'alias' => 'alias1' }
          ]
        }
      end

      it { expect(group.target_names.to_a).to eq(%w[target1]) }
      it { expect(group.target_aliases).to eq('alias1' => 'target1') }
    end

    context 'alias to a target in parent group' do
      let(:data) do
        {
          'name' => 'root',
          'targets' => [
            { 'name' => 'target1', 'alias' => 'alias1' }
          ],
          'groups' => [
            { 'name' => 'group1', 'targets' => ['target1'] }
          ]
        }
      end

      it { expect(group.target_names.to_a).to eq(%w[target1]) }
      it { expect(group.target_aliases).to eq('alias1' => 'target1') }
    end

    context 'alias to a target in sibling groups' do
      let(:data) do
        {
          'name' => 'root',
          'groups' => [
            { 'name' => 'group1', 'targets' => ['target1'] },
            { 'name' => 'group2', 'targets' => [{ 'name' => 'target1', 'alias' => 'alias1' }] }
          ]
        }
      end

      it { expect(group.target_names.to_a).to eq(%w[target1]) }
      it { expect(group.target_aliases).to eq('alias1' => 'target1') }
    end

    context 'non-string alias' do
      let(:data) do
        {
          'name' => 'root',
          'targets' => [
            { 'name' => 'target1', 'alias' => 42 }
          ]
        }
      end

      it { expect { group }.to raise_error(/Alias entry on target1 must be a String or Array/) }
    end

    context 'invalid alias name' do
      let(:data) do
        {
          'name' => 'root',
          'targets' => [
            { 'name' => 'target1', 'alias' => 'not a valid alias' }
          ]
        }
      end

      it { expect { group }.to raise_error(/Invalid alias not a valid alias/) }
    end

    context 'validating alias names' do
      let(:data) do
        {
          'name' => 'root',
          'targets' => [
            { 'name' => 'target1', 'alias' => @alias }
          ]
        }
      end

      %w[alias1 _alias1 1alias 1_alias_ alias-1 a 1].each do |alias_name|
        it "accepts '#{alias_name}'" do
          @alias = alias_name
          expect(group.target_aliases).to eq(alias_name => 'target1')
        end
      end

      %w[-alias1 alias/1 alias.1 - Alias1 ALIAS_1].each do |alias_name|
        it "rejects '#{alias_name}'" do
          @alias = alias_name
          expect { group }.to raise_error(/Invalid alias/)
        end
      end
    end

    context 'conflicting alias' do
      let(:data) do
        {
          'name' => 'root',
          'targets' => [
            { 'name' => 'target1', 'alias' => 'alias1' },
            { 'name' => 'target2', 'alias' => 'alias1' }
          ]
        }
      end

      it { expect { group }.to raise_error(/Alias alias1 refers to multiple targets: target1 and target2/) }
    end

    context 'conflict with a prior uri only name' do
      let(:data) do
        {
          'name' => 'root',
          'targets' => [
            { 'name' => 'target1' },
            { 'name' => 'target2', 'alias' => 'target1' }
          ]
        }
      end

      it { expect { group.validate }.to raise_error(/Node name target1 conflicts with alias of the same name/) }
    end

    context 'conflict with a later target name' do
      let(:data) do
        {
          'name' => 'root',
          'groups' => [
            { 'name' => 'group1', 'targets' => [{ 'name' => 'target1', 'alias' => 'target2' }] },
            { 'name' => 'group2', 'targets' => [{ 'name' => 'target2' }] }
          ]
        }
      end

      it { expect { group.validate }.to raise_error(/Node name target2 conflicts with alias of the same name/) }
    end

    context 'conflict with its own target name' do
      let(:data) do
        {
          'name' => 'root',
          'targets' => [
            { 'name' => 'target1' },
            {
              'name' => 'target2',
              'alias' => 'target1'
            }
          ]
        }
      end

      it 'raises an error' do
        expect { group.validate }.to raise_error(/Node name target1 conflicts with alias of the same name/)
      end
    end

    context 'conflict with a later group name' do
      let(:data) do
        {
          'name' => 'root',
          'targets' => [
            { 'name' => 'target1', 'alias' => 'group1' }
          ],
          'groups' => [
            { 'name' => 'group1' }
          ]
        }
      end

      it { expect { group.validate }.to raise_error(/Group group1 conflicts with alias of the same name/) }
    end

    context 'conflict with a prior group name' do
      let(:data) do
        {
          'name' => 'root',
          'groups' => [
            { 'name' => 'group1' },
            { 'name' => 'group2', 'targets' => [{ 'name' => 'target1', 'alias' => 'group1' }] }
          ]
        }
      end

      it { expect { group.validate }.to raise_error(/Group group1 conflicts with alias of the same name/) }
    end

    context 'conflict with its own group name' do
      let(:data) do
        {
          'name' => 'root',
          'targets' => [
            { 'name' => 'target1', 'alias' => 'root' }
          ]
        }
      end

      it { expect { group.validate }.to raise_error(/Group root conflicts with alias of the same name/) }
    end

    context 'conflicting alias across groups' do
      let(:data) do
        {
          'name' => 'root',
          'groups' => [
            { 'name' => 'group1', 'targets' => [{ 'name' => 'target2', 'alias' => 'alias1' }] },
            { 'name' => 'group2', 'targets' => [{ 'name' => 'target1', 'alias' => 'alias1' }] }
          ]
        }
      end

      it { expect { group.validate }.to raise_error(/Alias alias1 refers to multiple targets: target1 and target2/) }
    end

    context 'with unexpected keys' do
      let(:mock_logger) { instance_double("Logging.logger") }
      before(:each) do
        allow(Logging).to receive(:logger).and_return(mock_logger)
        allow(mock_logger).to receive(:[]).and_return(mock_logger)
      end

      it 'does not log when no unexpected keys are present' do
        expect(mock_logger).not_to receive(:warn)
        Bolt::Inventory::Group2.new('name' => 'foo', 'targets' => [{ 'name' => 'bar' }])
      end

      it 'logs unexpected group keys' do
        expect(mock_logger).to receive(:warn).with(/in group foo/)
        Bolt::Inventory::Group2.new('name' => 'foo', 'unexpected' => 1)
      end

      it 'logs unexpected group config keys' do
        expect(mock_logger).to receive(:warn).with(/in config for group foo/)
        Bolt::Inventory::Group2.new('name' => 'foo', 'config' => { 'unexpected' => 1 })
      end

      it 'logs unexpected target keys' do
        expect(mock_logger).to receive(:warn).with(/in target bar/)
        Bolt::Inventory::Group2.new('name' => 'foo', 'targets' => [
                                      { 'name' => 'bar', 'unexpected' => 1 }
                                    ])
      end

      it 'logs unexpected target config keys' do
        expect(mock_logger).to receive(:warn).with(/in config for target bar/)
        Bolt::Inventory::Group2.new('name' => 'foo', 'targets' => [
                                      { 'name' => 'bar', 'config' => { 'unexpected' => 1 } }
                                    ])
      end
    end
  end
end
