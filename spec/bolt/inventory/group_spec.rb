# frozen_string_literal: true

require 'spec_helper'
require 'bolt/inventory'
require 'bolt/inventory/group'
require 'bolt/plugin'
require 'bolt_spec/config'
require 'bolt_spec/plugins'

# This is largely internal and probably shouldn't be tested
describe Bolt::Inventory::Group do
  include BoltSpec::Config

  let(:data) { { 'name' => 'all' } }
  let(:pal) { nil } # Not used
  let(:plugins) { Bolt::Plugin.setup(config, nil, Bolt::Analytics::NoopClient.new) }
  let(:group) {
    # Inventory always resolves unknown labels to names or aliases from the top-down when constructed,
    # passing the collection of all aliases in it. Do that manually here to ensure plain target strings
    # are included as targets.
    g = Bolt::Inventory::Group.new(data, plugins)
    g.resolve_string_targets(g.target_aliases, g.all_targets)
    g
  }

  it 'returns nil' do
    expect(group.target_collect('target1')).to be_nil
    expect(group.group_collect('target1')).to be_nil
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

    it 'should return empty data' do
      expect(group.target_collect('target1')).to eq('config' => {},
                                                    'vars' => {},
                                                    'name' => nil,
                                                    'plugin_hooks' => {},
                                                    'uri' => 'target1',
                                                    'alias' => nil,
                                                    'facts' => {},
                                                    'features' => Set.new,
                                                    'groups' => [])
    end

    it 'should find three targets' do
      expect(group.all_targets.to_a.sort).to eq(%w[target1 target2 target3])
    end

    it 'should collect one group' do
      groups = group.collect_groups
      expect(groups.size).to eq(1)
      expect(groups['group1']).to eq(group)
    end

    it 'should return a hash for a string target' do
      expect(group.target_collect('target1')).to be
    end

    it 'should return a hash for hash defined targets' do
      expect(group.target_collect('target2')).to be
    end

    it 'should return nil for an unknown target' do
      expect(group.target_collect('target5')).to be_nil
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

    it 'should find one target' do
      expect(group.all_targets.to_a).to eq(%w[target1])
    end

    it 'should collect 2 groups' do
      groups = group.collect_groups
      expect(groups.size).to eq(2)
      expect(groups['group0']).to eq(group)
      expect(groups['group1'].name).to eq('group1')
    end

    it 'should find one target in the subgroup' do
      groups = group.collect_groups
      expect(groups['group1'].all_targets.to_a).to eq(%w[target1])
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
      expect(group.all_targets.to_a).to eq(%w[127.0.0.1 2001:db8:0:1:8080])
    end

    it 'should collect 2 groups' do
      groups = group.collect_groups
      expect(groups.size).to eq(2)
      expect(groups['group0']).to eq(group)
      expect(groups['group1'].name).to eq('group1')
    end

    it 'should find one target in the subgroup' do
      groups = group.collect_groups
      expect(groups['group1'].all_targets.to_a).to eq(%w[2001:db8:0:1:8080])
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
      expect(group.all_targets.to_a).to eq(%w[ssh://127.0.0.1:22 127.0.0.1])
    end
  end

  context 'with a duplicate target' do
    let(:data) do
      {
        'name' => 'group1',
        'targets' => [
          { 'name' => 'target1',
            'vars' => { 'val' => 'a' } },
          { 'name' => 'target1',
            'vars' => { 'val' => 'b' } }
        ]
      }
    end

    it 'uses the first value' do
      expect(group.target_collect('target1').dig('vars', 'val')).to eq('a')
    end
  end

  context 'where a target uses an invalid uri' do
    let(:data) do
      {
        'name' => 'group1',
        'targets' => [{ 'uri' => 'foo:a/b@neptune"' }]
      }
    end

    it 'raises an error' do
      expect { group.validate }.to raise_error(Bolt::Inventory::ValidationError, /Invalid target uri/)
    end
  end

  context 'where a target uses an invalid name' do
    let(:data) do
      {
        'name' => 'group1',
        'targets' => [{ 'name' => 'ฒณดตษ๚' }]
      }
    end

    it 'raises an error' do
      expect { group.validate }.to raise_error(Bolt::Inventory::ValidationError, /Target name must be ASCII/)
    end
  end

  context 'where a target name is not a string' do
    let(:data) do
      {
        'name' => 'group1',
        'targets' => [{ 'name' => ['foo'] }]
      }
    end

    it 'raises an error' do
      expect { group.validate }.to raise_error(Bolt::Inventory::ValidationError, /Target name must be a String/)
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
            'targets' => [{ 'name' => 'footarget', 'config' => 'foo' }]
          }
        ]
      }
    end

    it 'raises an error' do
      expect { group.validate }.to raise_error(
        Bolt::Inventory::ValidationError,
        /Expected config to be of type Hash.*for target footarget/
      )
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
        expect(group.all_targets).to include('target1')
      end

      it 'overrides parent group data with child group data' do
        expect(group.group_collect('target1')['vars']).to eq('foo' => 'bar', 'a' => 'b')
      end

      it 'combines parent group features with child group features' do
        expect(group.group_collect('target1')['features']).to match_array(%w[a b])
      end

      it 'returns the whole ancestry as the list of groups for the target' do
        expect(group.group_collect('target1')['groups']).to eq(%w[child parent root])
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
        expect(group.all_targets.to_a.sort).to eq(%w[target1 target2])
      end

      it 'overrides parent group data with child group data' do
        expect(group.group_collect('target1')['vars']).to eq('foo' => 'bar', 'a' => 'b')
        expect(group.group_collect('target2')['vars']).to eq('foo' => 'baz', 'a' => 'b')
      end

      it 'returns the whole ancestry as the list of groups for the target' do
        expect(group.group_collect('target1')['groups']).to eq(%w[child1 parent root])
        expect(group.group_collect('target2')['groups']).to eq(%w[child2 parent root])
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
      expect(group.group_collect('target1')['groups']).to eq(%w[parent1 child1 parent2 root])
      expect(group.group_collect('target1')['vars']).to eq('foo' => 'bar', 'a' => 'b')
      expect(group.group_collect('target1')['features']).to match_array(%w[a b])
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

    it 'fails if vars is not a hash' do
      data['vars'] = ['foo=bar']
      expect { group }.to raise_error(/Expected vars to be of type Hash/)
    end

    it 'fails if facts is not a hash' do
      data['facts'] = ['foo=bar']
      expect { group }.to raise_error(/Expected facts to be of type Hash/)
    end

    it 'fails if features is not an array' do
      data['features'] = 'shell'
      expect { group }.to raise_error(/Expected features to be of type Array/)
    end

    it 'fails if config is not a hash' do
      data['config'] = 'transport=ssh'
      expect { group }.to raise_error(/Expected config to be of type Hash/)
    end

    it 'fails if plugin_hooks is not a hash' do
      data['plugin_hooks'] = 'puppet_library'
      expect { group }.to raise_error(/Expected plugin_hooks to be of type Hash/)
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

      it { expect(group.all_targets.to_a).to eq(%w[target1]) }
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

      it { expect(group.all_targets.to_a).to eq(%w[target1 target2]) }
      it { expect(group.target_aliases).to eq('alias1' => 'target1', 'alias2' => 'target1', 'alias3' => 'target2') }
    end

    context 'multiple aliases in multiple groups' do
      let(:data) do
        {
          'name' => 'root',
          'groups' => [
            { 'name' => 'group1', 'targets' => [{ 'name' => 'target', 'alias' => 'alias1' }] },
            { 'name' => 'group2', 'targets' => [{ 'name' => 'target', 'alias' => 'alias2' }] }
          ]
        }
      end

      it { expect(group.target_aliases).to eq('alias1' => 'target', 'alias2' => 'target') }
      it { expect(group.target_collect('target')['alias']).to eq(%w[alias2 alias1]) }
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

      it { expect(group.all_targets.to_a).to eq(%w[target1]) }
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

      it { expect(group.all_targets.to_a).to eq(%w[target1]) }
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

      it { expect(group.all_targets.to_a).to eq(%w[target1]) }
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

      it { expect { group.validate }.to raise_error(/Target name target1 conflicts with alias of the same name/) }
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

      it { expect { group.validate }.to raise_error(/Target name target2 conflicts with alias of the same name/) }
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
        expect { group.validate }.to raise_error(/Target name target1 conflicts with alias of the same name/)
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
        Bolt::Inventory::Group.new({ 'name' => 'foo', 'targets' => [{ 'name' => 'bar' }] }, plugins)
      end

      it 'logs unexpected group keys' do
        expect(mock_logger).to receive(:warn).with(/in group foo/)
        Bolt::Inventory::Group.new({ 'name' => 'foo', 'unexpected' => 1 }, plugins)
      end

      it 'errors on deprecated nodes key' do
        expect {
          Bolt::Inventory::Group.new({ 'name' => 'foo', 'nodes' => [{ 'uri' => 'example.com' }] }, plugins)
        }.to raise_error(/Found 'nodes' key/)
      end

      it 'logs unexpected group config keys' do
        expect(mock_logger).to receive(:warn).with(/in config for group foo/)
        Bolt::Inventory::Group.new({ 'name' => 'foo', 'config' => { 'unexpected' => 1 } }, plugins)
      end

      it 'logs unexpected target keys' do
        expect(mock_logger).to receive(:warn).with(/in target bar/)
        Bolt::Inventory::Group.new({ 'name' => 'foo', 'targets' => [
                                     { 'name' => 'bar', 'unexpected' => 1 }
                                   ] }, plugins)
      end

      it 'logs unexpected target config keys' do
        expect(mock_logger).to receive(:warn).with(/in config for target bar/)
        Bolt::Inventory::Group.new({ 'name' => 'foo', 'targets' => [
                                     { 'name' => 'bar', 'config' => { 'unexpected' => 1 } }
                                   ] }, plugins)
      end
    end
  end

  describe "defining a group with plugins" do
    let(:data) do
      {
        'name' => 'root',
        'targets' => ['foo.example.com', 'bar.example.com'],
        'groups' => [{ 'name' => 'foo_group' }],
        'vars' => { 'key' => 'value' },
        'facts' => { 'osfamily' => 'windows' },
        'features' => ['shell'],
        'config' => { 'transport' => 'ssh' },
        'plugin_hooks' => { 'puppet_library' => { 'plugin' => 'install_puppet' } }
      }
    end

    let(:lookup_data) { {} }

    let(:modulepath) { [''] }
    let(:pal) { Bolt::PAL.new(modulepath, nil, nil) }

    let(:plugins) do
      plugins = Bolt::Plugin.setup(config, pal, Bolt::Analytics::NoopClient.new)
      plugins.add_plugin(BoltSpec::Plugins::Constant.new)
      plugins.add_plugin(BoltSpec::Plugins::Error.new)
      plugins.add_plugin(BoltSpec::Plugins::TestLookup.new(lookup_data))
      plugins
    end

    # Returns a reference to the 'constant' plugin with the specified value
    def constant(value)
      { '_plugin' => 'constant', 'value' => value }
    end

    it "fails if any keys are specified as plugins" do
      data.replace('name' => 'testgroup', constant('groups') => [])
      expect { group }.to raise_error(Bolt::Inventory::ValidationError, /keys cannot be specified as _plugin/)
    end

    context "defining the entire group with a plugin" do
      it 'evaluates a single plugin' do
        data.replace(constant('name' => 'testgroup', 'config' => { 'transport' => 'ssh' }))
        expect(group.name).to eq('testgroup')
        expect(group.group_data['config']).to eq('transport' => 'ssh')
      end

      it 'evaluates a plugin that returns a plugin' do
        lookup_data['groupdata'] = constant('name' => 'testgroup', 'config' => { 'transport' => 'ssh' })
        data.replace('_plugin' => 'test_lookup', 'key' => 'groupdata')
        expect(group.name).to eq('testgroup')
        expect(group.group_data['config']).to eq('transport' => 'ssh')
      end

      it 'evaluates a plugin with nested plugins' do
        data.replace(constant('name' => 'testgroup', 'config' => { 'ssh' => { 'port' => constant(3456) } }))
        expect(group.name).to eq('testgroup')
        expect(group.group_data['config']).to eq('ssh' => { 'port' => 3456 })
      end

      it 'does lazily evaluates plugins in the config section' do
        lookup_data['groupdata'] = { 'name' => 'testgroup', 'config' => { '_plugin' => 'error' } }
        data.replace('_plugin' => 'test_lookup', 'key' => 'groupdata')
        expect { group }.not_to raise_error
        expect(group.name).to eq('testgroup')
        expect { group.group_data }.to raise_error(/The Error plugin was called/)
      end
    end

    context "defining the targets list with a plugin" do
      it 'evaluates a single plugin' do
        data['targets'] = constant([{ 'name' => 'foo' }, { 'name' => 'bar' }])
        expect(group.local_targets).to eq(Set.new(%w[foo bar]))
      end

      it 'evaluates multiple plugins and concatenates the target lists' do
        data['targets'] = [
          constant([{ 'name' => 'foo' }, { 'name' => 'bar' }]),
          constant([{ 'name' => 'baz' }, { 'name' => 'quux' }])
        ]
        expect(group.local_targets).to eq(Set.new(%w[foo bar baz quux]))
      end

      it 'lazily evaluates plugins in the config section of a target' do
        data['targets'] = [
          { 'name' => 'foo', 'config' => { 'transport' => { '_plugin' => 'error' } } }
        ]
        expect { group }.not_to raise_error
        expect { group.group_data }.not_to raise_error
        expect { group.target_collect('foo') }.to raise_error(/The Error plugin was called/)
      end

      it 'allows a plugin to return an array of plugins' do
        lookup_data['target_list'] = [constant('foo'), constant('bar')]
        data['targets'] = { '_plugin' => 'test_lookup', 'key' => 'target_list' }
        expect(group.local_targets).to eq(Set.new(%w[foo bar]))
      end

      it 'allows a plugin to return an array of plugins which return arrays of plugins' do
        lookup_data['level3'] = [{ 'name' => 'foo' }, { 'name' => 'bar' }]
        lookup_data['level2'] = [{ '_plugin' => 'test_lookup', 'key' => 'level3' }]
        lookup_data['level1'] = [{ '_plugin' => 'test_lookup', 'key' => 'level2' }]
        data['targets'] = { '_plugin' => 'test_lookup', 'key' => 'level1' }
        expect(group.local_targets).to eq(Set.new(%w[foo bar]))
      end

      it 'allows the target list to be specified with arbitrarily nested arrays of plugins' do
        lookup_data['target_plugin'] = [[[[constant([{ 'name' => 'foo' }, { 'name' => 'bar' }])]]]]
        data['targets'] = [[[[{ '_plugin' => 'test_lookup', 'key' => 'target_plugin' }]]]]
        expect(group.local_targets).to eq(Set.new(%w[foo bar]))
      end

      it 'evaluates a plugin that returns a list of strings' do
        data['targets'] = constant(%w[foo bar])
        expect(group.local_targets).to eq(Set.new(%w[foo bar]))
      end

      it 'allows mixing plugins and literal targets' do
        data['targets'] = [
          constant([{ 'name' => 'foo' }]),
          { 'name' => 'bar' }
        ]
        expect(group.local_targets).to eq(Set.new(%w[foo bar]))
      end
    end

    context "defining the group data with plugins" do
      it 'lazily evaluates plugins in the config section' do
        data['config'] = { '_plugin' => 'error' }
        expect { group }.not_to raise_error
        expect { group.group_data }.to raise_error(/The Error plugin was called/)
      end

      it 'evaluates a plugin to set name' do
        data['name'] = constant('testgroup')
        expect(group.name).to eq('testgroup')
      end

      it 'evaluates a plugin with a nested plugin to set name' do
        data['name'] = constant(constant('testgroup'))
        expect(group.name).to eq('testgroup')
      end

      it 'evaluates a plugin that returns a plugin to set name' do
        lookup_data['group_name'] = constant('testgroup')
        data['name'] = { '_plugin' => 'test_lookup', 'key' => 'group_name' }
        expect(group.name).to eq('testgroup')
      end

      context "setting config" do
        it 'sets the value of a top-level setting' do
          data['config']['transport'] = constant('winrm')
          expect(group.group_data['config']['transport']).to eq('winrm')
        end

        it 'sets the value of a transport-specific setting' do
          data['config']['ssh'] = { 'port' => constant(9876) }
          expect(group.group_data.dig('config', 'ssh', 'port')).to eq(9876)
        end

        it 'sets the value of the entire "config" hash' do
          data['config'] = constant('transport' => 'winrm',
                                    'winrm' => { 'port' => 9876 })
          expect(group.group_data['config']).to eq('transport' => 'winrm', 'winrm' => { 'port' => 9876 })
        end

        it 'fails if the value of "config" is not a hash' do
          data['config'] = constant('ssh')
          expect { group.group_data['config'] }.to raise_error(/Expected config to be of type Hash/)
        end
      end

      context "setting vars" do
        it 'sets the value of a single var' do
          data['vars']['key2'] = constant('value2')
          expect(group.group_data['vars']).to eq('key' => 'value', 'key2' => 'value2')
        end

        it 'sets the value of a nested var' do
          data['vars']['key2'] = { 'foo' => constant('bar') }
          expect(group.group_data['vars']).to eq('key' => 'value', 'key2' => { 'foo' => 'bar' })
        end

        it 'sets the value of the entire "vars" hash' do
          data['vars'] = constant('foo' => 'bar', 'baz' => 'quux')
          expect(group.group_data['vars']).to eq('foo' => 'bar', 'baz' => 'quux')
        end

        it 'fails if the value of "vars" is not a hash' do
          data['vars'] = constant('foo=bar')
          expect { group.group_data['vars'] }.to raise_error(/Expected vars to be of type Hash/)
        end
      end

      context "setting facts" do
        it 'sets the value of a single fact' do
          data['facts']['ipaddress'] = constant('10.0.1.0')
          expect(group.group_data['facts']).to eq('osfamily' => 'windows', 'ipaddress' => '10.0.1.0')
        end

        it 'sets the value of a nested fact' do
          data['facts']['os'] = { 'name' => constant('windows') }
          expect(group.group_data['facts']).to eq('osfamily' => 'windows', 'os' => { 'name' => 'windows' })
        end

        it 'sets value of the entire "facts" hash' do
          data['facts'] = constant('osfamily' => 'Ubuntu', 'os' => { 'name' => 'Ubuntu' })
          expect(group.group_data['facts']).to eq('osfamily' => 'Ubuntu', 'os' => { 'name' => 'Ubuntu' })
        end

        it 'fails if the value of "facts" is not a hash' do
          data['facts'] = constant(%w[foo bar])
          expect { group.group_data['facts'] }.to raise_error(/Expected facts to be of type Hash/)
        end
      end

      context "setting features" do
        it 'adds a single feature' do
          data['features'] << constant('puppet-agent')
          expect(group.group_data['features']).to eq(Set['shell', 'puppet-agent'])
        end

        it 'adds a nested array of features' do
          data['features'] << constant(%w[puppet-agent python])
          expect(group.group_data['features']).to eq(Set['shell', 'puppet-agent', 'python'])
        end

        it 'sets the value of the entire "features" array' do
          data['features'] = constant(%w[puppet-agent shell python])
          expect(group.group_data['features']).to eq(Set['puppet-agent', 'shell', 'python'])
        end

        it 'fails if the value of "features" is not an array' do
          data['features'] = constant('puppet-agent')
          expect { group.group_data['features'] }.to raise_error(/Expected features to be of type Array/)
        end
      end

      context "setting plugin_hooks" do
        it 'sets the value of a single plugin_hook' do
          data['plugin_hooks']['another_hook'] = constant('plugin' => 'task', 'task' => 'do_a_thing')
          expect(group.group_data['plugin_hooks']).to eq(
            'puppet_library' => { 'plugin' => 'install_puppet' },
            'another_hook' => { 'plugin' => 'task', 'task' => 'do_a_thing' }
          )
        end

        it 'sets the value of one setting of a plugin_hook' do
          data['plugin_hooks']['puppet_library']['plugin'] = constant('alternate_install')
          expect(group.group_data['plugin_hooks']).to eq('puppet_library' => { 'plugin' => 'alternate_install' })
        end

        it 'sets the value of the entire "plugin_hooks" hash' do
          plugin_hooks = {
            'puppet_library' => { 'plugin' => 'something' },
            'another_hook' => { 'plugin' => 'something_else' }
          }
          data['plugin_hooks'] = constant(plugin_hooks)
          expect(group.group_data['plugin_hooks']).to eq(plugin_hooks)
        end

        it 'fails of the value of "plugin_hooks" is not a hash' do
          data['plugin_hooks'] = constant('puppet_library')
          expect { group.group_data['plugin_hooks'] }.to raise_error(/Expected plugin_hooks to be of type Hash/)
        end
      end

      it 'allows the value of a plugin to be passed as an argument to another plugin' do
        # This should evaluate the constant plugin and return foo, then pass
        # that to the lookup plugin which will find the value bar. If it
        # evaluates in the wrong order, it will try to lookup with the plugin
        # invocation as the key and return nil
        lookup_data['foo'] = 'winrm'
        data['config']['transport'] = { '_plugin' => 'test_lookup', 'key' => constant('foo') }
        expect(group.group_data['config']['transport']).to eq('winrm')
      end

      it 'allows a plugin to return a reference to another plugin' do
        # The lookup plugin will return a reference to the constant plugin, which will then return 3456
        lookup_data['foo'] = constant(3456)
        data['config']['ssh'] = { 'port' => { '_plugin' => 'test_lookup', 'key' => 'foo' } }
        expect(group.group_data.dig('config', 'ssh', 'port')).to eq(3456)
      end

      it 'allows a plugin to return a nested plugin reference' do
        lookup_data['ssh_config'] = {
          'port' => 3456,
          'password' => { '_plugin' => 'test_lookup', 'key' => 'ssh_password' }
        }
        lookup_data['ssh_password'] = constant('secret_password')
        data['config']['ssh'] = { '_plugin' => 'test_lookup', 'key' => 'ssh_config' }
        expect(group.group_data['config']['ssh']).to eq('port' => 3456, 'password' => 'secret_password')
      end
    end
  end
end
