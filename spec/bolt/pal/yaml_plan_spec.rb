# frozen_string_literal: true

require 'spec_helper'
require 'bolt/pal'
require 'bolt/pal/yaml_plan'

describe Bolt::PAL::YamlPlan do
  let(:plan_name) { Puppet::Pops::Loader::TypedName.new(:plan, 'test') }
  let(:pal) { Bolt::PAL.new([], nil) }
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
          'nodes' => {
            'type' => 'TargetSpec'
          },
          'package' => {
            'type' => 'String'
          },
          'count' => {
            'type' => 'Integer'
          }
        }
      }

      param_types = plan.parameters.inject({}) { |acc, param| acc.merge(param.name => param.type_expr) }

      expect(param_types.keys).to contain_exactly('nodes', 'package', 'count')
      expect(param_types['nodes'].name).to eq('TargetSpec')
      expect(param_types['package']).to be_a(Puppet::Pops::Types::PStringType)
      expect(param_types['count']).to be_a(Puppet::Pops::Types::PIntegerType)
    end

    it 'handles parameters without types' do
      @plan_body = {
        'parameters' => {
          'empty' => {},
          'nil' => nil
        }
      }

      expect(plan.parameters.map(&:name)).to contain_exactly('empty', 'nil')
      expect(plan.parameters.map(&:type_expr)).to eq([nil, nil])
    end

    it 'uses an empty parameter list if none are specified' do
      @plan_body = {}

      expect(plan.parameters).to eq([])
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
    end
  end
end
