# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/pal'

describe Bolt::PAL do
  include BoltSpec::PAL

  before(:all) do
    Puppet.settings.send(:clear_everything_for_tests)
    Bolt::PAL.load_puppet
  end
  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  let(:project) { Bolt::Project.new({ 'name' => 'pal_test' }, Dir.getwd) }

  describe :parse_manifest do
    let(:pal) { Bolt::PAL.new(Bolt::Config::Modulepath.new([]), nil, nil) }

    it "should parse a manifest string" do
      ast = pal.parse_manifest('notify { "hello world": }', 'test.pp')
      expect(ast).to be_a(Puppet::Pops::Model::Program)
    end

    it "should convert puppet errors to pal errors" do
      expect { pal.parse_manifest('notify { "hello world" }', 'test.pp') }
        .to raise_error(Bolt::PAL::PALError, /Failed to parse manifest.*test.pp/)
    end
  end

  describe :parse_param do
    let(:metadata) do
      { parameters: {
        string: { type: 'String' },
        opt_string: { type: 'Optional[String]' },
        length_string: { type: 'String[10]' },
        variant_string: { type: 'Variant[String, Boolean]' },
        data: { type: 'Data' },
        pattern: { type: 'Pattern[/foo/]' },
        bool: { type: 'Boolean' },
        integer: { type: 'Integer' },
        array: { type: 'Array[Data]' },
        hash: { type: 'Hash[String, Data]' },
        alias: { type: 'TargetSpec' }
      } }
    end

    let(:mods) do
      { 'testmod' => {
        'tasks' => {
          'init.json' => metadata.to_json,
          'init.sh' => "empty"
        },
        'plans' => {
          'init.pp' => <<~PUPPET
                         plan testmod(
                           String[1] $string,
                           Boolean $bool,
                         ) {}
                       PUPPET
        }
      } }
    end

    def parse_params(params)
      pal_with_module_content(mods) do |pal|
        pal.parse_params('task', 'testmod', params)
      end
    end

    it 'should accept an unquoted string as String' do
      expect(parse_params('string' => 'foo')).to eq('string' => 'foo')
    end

    it 'should accept an unquoted string as Optional[String]' do
      expect(parse_params('opt_string' => 'foo')).to eq('opt_string' => 'foo')
    end

    it 'should parse a quoted string thats long enough String[10]' do
      str = 'foooooooooo'
      expect(parse_params('length_string' => "\"#{str}\"")).to eq('length_string' => str)
    end

    it 'should not parse a quoted string thats too short String[10]' do
      str = '"foooooooo"'
      # CODEREVIEW: This behavior may be a bit weird since the string is valid
      # when it included the quotes and will be used by the task/plan
      expect(parse_params('length_string' => str)).to eq('length_string' => str)
    end

    it 'should parse a quoted string for String' do
      expect(parse_params('string' => '"foo"')).to eq('string' => 'foo')
    end

    it 'should parse a quoted string for pattern' do
      expect(parse_params('pattern' => '"foo"')).to eq('pattern' => 'foo')
    end

    it 'should parse a bool for Variant[String, Boolean]' do
      expect(parse_params('variant_string' => 'false')).to eq('variant_string' => false)
    end

    it 'should not parse a quoted bool for Variant[String, Boolean]' do
      expect(parse_params('variant_string' => '"false"')).to eq('variant_string' => 'false')
    end

    it 'should parse a bool for data' do
      expect(parse_params('data' => 'false')).to eq('data' => false)
    end

    it 'should parse a bool for Boolean' do
      expect(parse_params('bool' => 'false')).to eq('bool' => false)
    end

    it 'should parse an integer for integer' do
      expect(parse_params('integer' => '100')).to eq('integer' => 100)
    end

    it 'should parse an array for Array' do
      arr = [1, "two", ['three']]
      expect(parse_params('array' => arr.to_json)).to eq('array' => arr)
    end

    it 'should parse an object for Hash' do
      obj = { 'this' => 1, 'that' => "two" }
      expect(parse_params('hash' => obj.to_json)).to eq('hash' => obj)
    end

    it 'should parse an object for a type alias' do
      arr = %w[node1 node2 node3]
      expect(parse_params('array' => arr.to_json)).to eq('array' => arr)
    end

    it 'parses_multiple_params' do
      expect(parse_params('integer' => '100', 'string' => '"foo"')).to eq('integer' => 100, 'string' => 'foo')
    end

    it 'works for params from a plan' do
      params = { 'string' => '"foo"',
                 'bool' => 'true' }
      parsed = pal_with_module_content(mods) do |pal|
        pal.parse_params('plan', 'testmod', params)
      end
      expect(parsed).to eq('string' => 'foo', 'bool' => true)
    end
  end

  describe :in_bolt_compiler do
    it "sets the bolt_project in the context" do
      pal = Bolt::PAL.new(Bolt::Config::Modulepath.new([]), nil, nil, 1, nil, {}, project)
      pal.in_bolt_compiler do
        expect(Puppet.lookup(:bolt_project).name).to eq(project.name)
      end
    end
  end

  describe :show_module do
    let(:metadata)   { JSON.parse(File.read(fixtures_path('modules', 'sample', 'metadata.json'))) }
    let(:modulepath) { Bolt::Config::Modulepath.new([fixtures_path('modules')]) }
    let(:pal)        { Bolt::PAL.new(modulepath, nil, nil) }

    it 'accepts short name' do
      allow(pal).to receive_messages(list_plans_with_cache: [], list_tasks_with_cache: [])
      expect { pal.show_module('sample') }.not_to raise_error
    end

    it 'accepts forge name with /' do
      allow(pal).to receive_messages(list_plans_with_cache: [], list_tasks_with_cache: [])
      expect { pal.show_module('bolt/sample') }.not_to raise_error
    end

    it 'accepts forge name with -' do
      allow(pal).to receive_messages(list_plans_with_cache: [], list_tasks_with_cache: [])
      expect { pal.show_module('bolt-sample') }.not_to raise_error
    end

    it 'errors with unknown module' do
      expect { pal.show_module('abcdefg') }.to raise_error(
        Bolt::Error,
        /Could not find module 'abcdefg' on the modulepath/
      )
    end

    it 'returns expected data' do
      result = pal.show_module('bolt/sample')

      expect(result.keys).to match_array(%i[metadata name path plans tasks]),
                             'Does not return expected keys'

      expect(result[:name]).to eq('bolt/sample'),
                               'Does not return Forge name'

      expect(result[:path]).to eq(fixtures_path('modules', 'sample')),
                               'Does not return path to module'

      expect(result[:plans]).to include(
        ['sample::single_task', 'one line plan to show we can run a task by name'],
        ['sample::yaml', nil]
      ),
                                'Does not return plan list'

      expect(result[:tasks]).to include(
        ['sample::multiline', 'Write a multiline string to the console']
      ),
                                'Does not return task list'

      expect(result[:metadata]).to match(metadata),
                                   'Does not return metadata'
    end
  end
end
