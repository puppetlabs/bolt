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

  describe :parse_manifest do
    let(:pal) { Bolt::PAL.new(Bolt::Config.default) }

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
      project = Bolt::Project.new({ 'name' => 'mytestproject' }, Dir.getwd)
      pal = Bolt::PAL.new(Bolt::Config.from_project(project, {}))
      pal.in_bolt_compiler do
        expect(Puppet.lookup(:bolt_project).name).to eq('mytestproject')
      end
    end
  end
end
