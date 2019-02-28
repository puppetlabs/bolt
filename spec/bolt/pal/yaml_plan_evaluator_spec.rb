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
      steps: nil
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

    it 'accepts a variable for target' do
      step['target'] = '$target'

      scope.with_local_scope('target' => 'bar.example.com') do |local_scope|
        args = ['package', 'bar.example.com', { 'action' => 'status', 'name' => 'openssl' }]
        expect(local_scope).to receive(:call_function).with('run_task', args)

        subject.task_step(local_scope, step)
      end
    end

    it 'accepts a variable for parameter values' do
      step['parameters'] = {
        'name' => '$package',
        'action' => 'status'
      }

      scope.with_local_scope('package' => 'vim') do |local_scope|
        args = ['package', 'foo.example.com', { 'action' => 'status', 'name' => 'vim' }]
        expect(local_scope).to receive(:call_function).with('run_task', args)

        subject.task_step(local_scope, step)
      end
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

    it 'accepts a variable for target' do
      step['target'] = '$target'

      scope.with_local_scope('target' => 'bar.example.com') do |local_scope|
        expect(local_scope).to receive(:call_function).with('run_command', ['hostname -f', 'bar.example.com'])

        subject.command_step(local_scope, step)
      end
    end

    it 'supports a description' do
      step['description'] = 'run the thing'

      expect(scope).to receive(:call_function).with('run_command', ['hostname -f', 'foo.example.com', 'run the thing'])
      subject.command_step(scope, step)
    end
  end

  describe "#interpolate_variables" do
    it 'returns non-String values unmodified' do
      [
        %w[a b c],
        5,
        true,
        nil,
        { 'a' => 1 },
        %w[$a $b $c],
        { '$a' => '$b' }
      ].each do |value|
        expect(subject.interpolate_variables(scope, value)).to eq(value)
      end
    end

    it 'replaces exact variable matches with their value' do
      scope.with_local_scope('message' => 'hello world') do |local_scope|
        expect(subject.interpolate_variables(local_scope, '$message')).to eq('hello world')
      end
    end

    it 'raises an error if an undefined variable is referenced' do
      scope.with_local_scope('message' => 'hello world') do |local_scope|
        expect { subject.interpolate_variables(local_scope, '$dressage') }.to raise_error(/Undefined variable/)
      end
    end

    # This one seems like it should work, but `${message}` is actually invalid
    # puppet code, because that form of variable reference needs to be inside a
    # string literal.
    it 'returns the string if it is wrapped in curly braces' do
      expect(subject.interpolate_variables(scope, '${message}')).to eq('${message}')
    end

    it 'returns the string if it is not a variable reference' do
      expect(subject.interpolate_variables(scope, 'foo')).to eq('foo')
    end

    it 'returns the string if it has an embedded variable reference' do
      expect(subject.interpolate_variables(scope, 'foo$bar')).to eq('foo$bar')
    end

    it 'returns the string if it includes complex interpolation' do
      expect(subject.interpolate_variables(scope, '${foo[0]}')).to eq('${foo[0]}')
    end

    it 'returns the string if it contains multiple variable interpolations' do
      expect(subject.interpolate_variables(scope, '$foo$bar')).to eq('$foo$bar')
    end
  end
end
