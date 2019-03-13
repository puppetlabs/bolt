# frozen_string_literal: true

require 'spec_helper'
require 'bolt/pal'
require 'bolt/pal/yaml_plan_evaluator'

describe Bolt::PAL::YamlPlanEvaluator do
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

  before :each do
    # Make sure we don't accidentally call any run functions
    allow(scope).to receive(:call_function)
  end

  def call_plan(plan, params = {})
    # This is taken from the boltlib::run_plan function
    catch(:return) {
      plan.class.dispatcher.dispatchers[0].call_by_name_with_scope(scope, params, true)
    }&.value
  end

  describe Bolt::PAL::YamlPlanEvaluator::PlanWrapper do
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

    it 'uses an empty parameter list if non are specified' do
      @plan_body = {}

      expect(plan.parameters).to eq([])
    end
  end

  describe "evaluating puppet code" do
    let(:evaluator) { Puppet::Pops::Parser::EvaluatingParser.new }
    describe Bolt::PAL::YamlPlanEvaluator::DoubleQuotedString do
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

    describe Bolt::PAL::YamlPlanEvaluator::CodeLiteral do
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

    describe Bolt::PAL::YamlPlanEvaluator::BareString do
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

  describe "::create" do
    it 'fails if the plan is not a Hash' do
      plan_body = '[]'

      expect { described_class.create(loader, plan_name, 'test.yaml', plan_body) }.to raise_error(
        ArgumentError, /test.yaml does not contain an object/
      )
    end

    it 'returns a puppet function wrapper' do
      plan_body = '{}'
      plan = described_class.create(loader, plan_name, 'test.yaml', plan_body)
      expect(plan).to be_a(Puppet::Functions::Function)
    end
  end

  describe "evaluating a plan" do
    it 'validates the parameters' do
      plan_body = <<-YAML
      parameters:
        foo:
          type: String
        bar:
          type: Integer

      steps: []
      YAML

      plan = described_class.create(loader, plan_name, 'test.yaml', plan_body)

      expect(call_plan(plan, 'foo' => 'hello', 'bar' => 5)).to eq(nil)
      expect(call_plan(plan, 'foo' => '', 'bar' => 5)).to eq(nil)

      expect { call_plan(plan, 'foo' => 'hello', 'bar' => 'five') }.to raise_error(
        Puppet::ParseError, /parameter 'bar' expects an Integer value, got String/
      )
      expect { call_plan(plan, 'foo' => 'hello') }.to raise_error(
        Puppet::ParseError, /expects a value for parameter 'bar'/
      )
      expect { call_plan(plan, 'foo' => 'hello', 'bar' => 5, 'baz' => true) }.to raise_error(
        Puppet::ParseError, /has no parameter named 'baz'/
      )
    end

    # a) empty array, b) nil, c) missing key
    it 'does nothing if the steps list is empty' do
      plan_body = <<-YAML
      steps: []
      YAML

      plan = described_class.create(loader, plan_name, 'test.yaml', plan_body)

      expect(scope).not_to receive(:call_function)

      expect(call_plan(plan)).to eq(nil)
    end

    it 'fails if the steps list is not an array' do
      plan_body = <<-YAML
      steps: null
      YAML

      plan = described_class.create(loader, plan_name, 'test.yaml', plan_body)

      expect { call_plan(plan) }.to raise_error(Bolt::Error, /Plan must specify an array of steps/)
    end

    it 'fails if the steps list is not specified' do
      plan_body = <<-YAML
      parameters: {}
      YAML

      plan = described_class.create(loader, plan_name, 'test.yaml', plan_body)

      expect { call_plan(plan) }.to raise_error(Bolt::Error, /Plan must specify an array of steps/)
    end

    it 'runs each step in order' do
      plan_body = <<-YAML
      parameters:
        package:
          type: String
        nodes:
          type: TargetSpec
      steps:
        - task: package
          target: $nodes
          parameters:
            action: status
            name: $package
        - command: hostname -f
          target: $nodes
      YAML

      plan = described_class.create(loader, plan_name, 'test.yaml', plan_body)

      nodes = %w[foo.example.com bar.example.com]
      params = { 'action' => 'status', 'name' => 'openssl' }
      expect(scope).to receive(:call_function).with('run_task', ['package', nodes, params]).ordered
      expect(scope).to receive(:call_function).with('run_command', ['hostname -f', nodes]).ordered

      call_plan(plan, 'package' => 'openssl', 'nodes' => nodes)
    end

    it 'can be run multiple times with different parameters' do
      plan_body = <<-YAML
      parameters:
        nodes:
          type: TargetSpec
      steps:
        - command: hostname -f
          target: $nodes
      YAML

      plan = described_class.create(loader, plan_name, 'test.yaml', plan_body)

      expect(scope).to receive(:call_function).with('run_command', ['hostname -f', ['foo.example.com']])
      call_plan(plan, 'nodes' => ['foo.example.com'])

      expect(scope).to receive(:call_function).with('run_command', ['hostname -f', ['bar.example.com']])
      call_plan(plan, 'nodes' => ['bar.example.com'])
    end

    # task+command
    it 'fails if a step is ambiguous' do
      plan_body = <<-YAML
      steps:
        - task: package
          command: yum install package
          target: ["foo.example.com"]
      YAML

      plan = described_class.create(loader, plan_name, 'test.yaml', plan_body)

      expect { call_plan(plan) }.to raise_error(Bolt::Error, /Unsupported plan step/)
    end

    it 'fails for an unknown step' do
      plan_body = <<-YAML
      steps:
        - package: openssl
          target: ["foo.example.com"]
      YAML

      plan = described_class.create(loader, plan_name, 'test.yaml', plan_body)

      expect { call_plan(plan) }.to raise_error(Bolt::Error, /Unsupported plan step/)
    end
  end

  describe "#task_step" do
    let(:step) do
      { 'task' => 'package',
        'target' => 'foo.example.com',
        'parameters' => { 'action' => 'status',
                          'name' => 'openssl' } }
    end

    it 'fails if no target is specified' do
      step.delete('target')

      expect { subject.task_step(scope, step) }.to raise_error(/Can't run a task without specifying a target/)
    end

    it 'succeeds if no parameters are specified' do
      step.delete('parameters')

      expect(scope).to receive(:call_function).with('run_task', ['package', 'foo.example.com', {}])
      subject.task_step(scope, step)
    end

    it 'succeeds if nil parameters are specified' do
      step['parameters'] = nil

      expect(scope).to receive(:call_function).with('run_task', ['package', 'foo.example.com', {}])
      subject.task_step(scope, step)
    end

    it 'supports a description' do
      step['description'] = 'run the thing'

      args = ['package', 'foo.example.com', 'run the thing', { 'action' => 'status', 'name' => 'openssl' }]
      expect(scope).to receive(:call_function).with('run_task', args)

      subject.task_step(scope, step)
    end
  end

  describe "#command_step" do
    let(:step) do
      { 'command' => 'hostname -f',
        'target' => 'foo.example.com' }
    end

    it 'fails if no target is specified' do
      step.delete('target')

      expect { subject.command_step(scope, step) }.to raise_error(/Can't run a command without specifying a target/)
    end

    it 'supports a description' do
      step['description'] = 'run the thing'

      expect(scope).to receive(:call_function).with('run_command', ['hostname -f', 'foo.example.com', 'run the thing'])
      subject.command_step(scope, step)
    end
  end
end
