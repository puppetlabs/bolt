# frozen_string_literal: true

require 'spec_helper'
require 'bolt/pal'
require 'bolt/pal/yaml_plan'

describe Bolt::PAL::YamlPlan do
  let(:plan_name) { Puppet::Pops::Loader::TypedName.new(:plan, 'test') }
  let(:pal) { Bolt::PAL.new([], nil, nil) }
  # It doesn't really matter which loader or scope we use, but we need them, so take the
  # static loader and global scope
  let(:loader) { Puppet.lookup(:loaders).static_loader }
  let(:scope) { Puppet.lookup(:global_scope) }

  around :each do |example|
    pal.in_bolt_compiler do
      example.run
    end
  end

  describe "creating a plan" do
    let(:plan) { described_class.new(plan_name, @plan_body) }

    it 'parses parameter types' do
      @plan_body = {
        'parameters' => {
          'targets' => {
            'type' => 'TargetSpec'
          },
          'package' => {
            'type' => 'String'
          },
          'count' => {
            'type' => 'Integer'
          }
        },
        'steps' => []
      }

      param_types = plan.parameters.inject({}) { |acc, param| acc.merge(param.name => param.type_expr) }

      expect(param_types.keys).to contain_exactly('targets', 'package', 'count')
      expect(param_types['targets'].name).to eq('TargetSpec')
      expect(param_types['package']).to be_a(Puppet::Pops::Types::PStringType)
      expect(param_types['count']).to be_a(Puppet::Pops::Types::PIntegerType)
    end

    it 'handles parameters without types' do
      @plan_body = {
        'parameters' => {
          'empty' => {},
          'nil' => nil
        },
        'steps' => []
      }

      expect(plan.parameters.map(&:name)).to contain_exactly('empty', 'nil')
      expect(plan.parameters.map(&:type_expr)).to eq([nil, nil])
    end

    it 'uses an empty parameter list if none are specified' do
      @plan_body = {
        'steps' => []
      }

      expect(plan.parameters).to eq([])
    end

    describe "plan validation" do
      let(:plan) { described_class.new(plan_name, @plan_body) }

      it 'fails if a parameter has a name that is not a valid variable name' do
        @plan_body = {
          'parameters' => { 'foo-bar' => {} },
          'steps' => []
        }

        expect { plan }.to raise_error(Bolt::Error, /Invalid parameter name "foo-bar"/)
      end

      it 'fails if a parameters is not a hash' do
        @plan_body = {
          'parameters' => nil,
          'steps' => []
        }

        expect { plan }.to raise_error(Bolt::Error, /Plan parameters must be a Hash/)
      end

      it 'fails if a step has the same name as a parameter' do
        @plan_body = {
          'parameters' => { 'foo' => {} },
          'steps' => [{ 'name' => 'foo',
                        'eval' => '$foo' }]
        }

        expect { plan }.to raise_error do |error|
          expect(error.kind).to eq('bolt/invalid-plan')
          expect(error.message).to match(/Parse error in step "foo"/)
          expect(error.message).to match(/Duplicate step name or parameter detected: "foo"/)
        end
      end

      it 'fails if invalid top level key is specified' do
        @plan_body = {
          'parameters' => { 'foo' => {} },
          'steps' => [],
          'foo' => 'bar'
        }

        expect { plan }.to raise_error(Bolt::Error, /Plan contains illegal key\(s\) \["foo"\]/)
      end

      it 'fails if two steps have the same name' do
        @plan_body = {
          'steps' => [
            { 'name' => 'foo',
              'eval' => '$foo' },
            { 'name' => 'foo',
              'eval' => '$foo' }
          ]
        }

        expect { plan }.to raise_error do |error|
          expect(error.kind).to eq('bolt/invalid-plan')
          expect(error.message).to match(/Parse error in step "foo"/)
          expect(error.message).to match(/Duplicate step name or parameter detected: "foo"/)
        end
      end

      it 'fails if a step has a name that is not a valid variable name' do
        @plan_body = {
          'steps' => [
            { 'name' => 'foo-bar',
              'eval' => '$foo' }
          ]
        }

        expect { plan }.to raise_error do |error|
          expect(error.kind).to eq('bolt/invalid-plan')
          expect(error.message).to match(/Parse error in step "foo-bar"/)
          expect(error.message).to match(/Invalid step name: "foo-bar"/)
        end
      end

      it 'fails if a step has multiple action keys' do
        @plan_body = {
          'steps' => [
            { 'name' => 'foo-bar',
              'eval' => '$foo',
              'task' => 'foo' }
          ]
        }

        expect { plan }.to raise_error do |error|
          expect(error.kind).to eq('bolt/invalid-plan')
          expect(error.message).to match(/Parse error in step "foo-bar"/)
          expect(error.message).to match(/Multiple action keys detected: \["eval", "task"\]/)
        end
      end

      it 'fails if a step has illegal keys' do
        @plan_body = {
          'steps' => [
            { 'description' => 'foo-bar',
              'eval' => '$foo',
              'bar' => 'foo' }
          ]
        }

        expect { plan }.to raise_error do |error|
          expect(error.kind).to eq('bolt/invalid-plan')
          expect(error.message).to match(/Parse error in step number 1/)
          expect(error.message).to match(/The "eval" step does not support: \["bar"\] key\(s\)/)
        end
      end

      it 'fails if a step is missing keys' do
        @plan_body = {
          'steps' => [
            { 'description' => 'foo-bar',
              'task' => '$foo',
              'name' => 'foo' }
          ]
        }

        expect { plan }.to raise_error do |error|
          expect(error.kind).to eq('bolt/invalid-plan')
          expect(error.message).to match(/Parse error in step "foo"/)
          expect(error.message).to match(/The "task" step requires: \["targets"\] key\(s\)/)
        end
      end

      it 'fails if the steps list is not an array' do
        @plan_body = {
          'steps' => nil
        }

        expect { plan }.to raise_error(Bolt::Error, /Plan must specify an array of steps/)
      end

      it 'fails if the steps list is not specified' do
        @plan_body = {}

        expect { plan }.to raise_error(Bolt::Error, /Plan must specify an array of steps/)
      end
    end
  end

  describe Bolt::PAL::YamlPlan::EvaluableString do
    let(:evaluator) { Puppet::Pops::Parser::EvaluatingParser.new }
    describe Bolt::PAL::YamlPlan::DoubleQuotedString do
      it "treats literal strings as literal strings" do
        str = described_class.new("hello world")
        expect(str.evaluate(scope, evaluator)).to eq("hello world")
      end

      it "keeps escaped characters escaped" do
        str = described_class.new("hello \" world")
        expect(str.evaluate(scope, evaluator)).to eq("hello \" world")
      end

      it "evaluates embedded variables" do
        str = described_class.new("hello $foo")
        scope.with_local_scope('foo' => 'world') do |local_scope|
          expect(str.evaluate(local_scope, evaluator)).to eq("hello world")
        end
      end

      it "fails if the variable is not set in scope" do
        str = described_class.new("hello $bar")
        expect { str.evaluate(scope, evaluator) }.to raise_error(Puppet::ParseError, /Unknown variable/)
      end

      it "evaluates complex variable expressions" do
        str = described_class.new("hello ${foo[0]}, brought to you by the numbers ${foo.length} and ${5+3}")
        scope.with_local_scope('foo' => ['world']) do |local_scope|
          expect(str.evaluate(local_scope, evaluator)).to eq("hello world, brought to you by the numbers 1 and 8")
        end
      end

      it "does not evaluate arbitrary puppet code outside an interpolation" do
        str = described_class.new("5+3")
        expect(str.evaluate(scope, evaluator)).to eq("5+3")
      end

      it "does not expose variable assignments to the outer scope" do
        str = described_class.new("${$foo = 5}")
        str.evaluate(scope, evaluator)

        expect { described_class.new("$foo").evaluate(scope, evaluator) }
          .to raise_error(Puppet::ParseError, /Unknown variable/)
      end
    end

    describe Bolt::PAL::YamlPlan::CodeLiteral do
      it "treats the string as arbitrary code" do
        str = described_class.new("5+3")
        expect(str.evaluate(scope, evaluator)).to eq(8)
      end

      it "evaluates function calls" do
        str = described_class.new("[1,2,3,4,5].map |$i| { $i + 2 }")
        expect(str.evaluate(scope, evaluator)).to eq([3, 4, 5, 6, 7])
      end

      it "interpolates within embedded double-quoted strings" do
        str = described_class.new('"hello $foo"')
        scope.with_local_scope('foo' => 'world') do |local_scope|
          expect(str.evaluate(local_scope, evaluator)).to eq("hello world")
        end
      end

      it "fails if the code can't be parsed" do
        str = described_class.new("invalid/puppet code")
        expect { str.evaluate(scope, evaluator) }.to raise_error(Puppet::ParseError)
      end

      it "does not expose variable assignments to the outer scope" do
        str = described_class.new("$foo = 5")
        str.evaluate(scope, evaluator)

        expect { described_class.new("$foo").evaluate(scope, evaluator) }
          .to raise_error(Puppet::ParseError, /Unknown variable/)
      end
    end

    describe Bolt::PAL::YamlPlan::BareString do
      it "evaluates the code if it starts with a $" do
        str = described_class.new("$foo")
        scope.with_local_scope('foo' => 'hello world') do |local_scope|
          expect(str.evaluate(local_scope, evaluator)).to eq("hello world")
        end
      end

      it "evaluates nested variable lookups" do
        str = described_class.new("$foo[0][$bar]")
        scope.with_local_scope('foo' => ['testkey' => 'hello world'], 'bar' => 'testkey') do |local_scope|
          expect(str.evaluate(local_scope, evaluator)).to eq("hello world")
        end
      end

      it "evaluates function calls" do
        str = described_class.new("$foo.map |$i| { $i + 2 }")
        scope.with_local_scope('foo' => [1, 2, 3, 4, 5]) do |local_scope|
          expect(str.evaluate(local_scope, evaluator)).to eq([3, 4, 5, 6, 7])
        end
      end

      it "evaluates math expressions" do
        str = described_class.new("$foo + 3")
        scope.with_local_scope('foo' => 5) do |local_scope|
          expect(str.evaluate(local_scope, evaluator)).to eq(8)
        end
      end

      it "treats the code as a plain string if it doesn't start with a $" do
        str = described_class.new("hello world")
        expect(str.evaluate(scope, evaluator)).to eq("hello world")
      end

      it "does not expose variable assignments to the outer scope" do
        str = described_class.new("$foo = 5")
        str.evaluate(scope, evaluator)

        expect { described_class.new("$foo").evaluate(scope, evaluator) }
          .to raise_error(Puppet::ParseError, /Unknown variable/)
      end
    end
  end
end
