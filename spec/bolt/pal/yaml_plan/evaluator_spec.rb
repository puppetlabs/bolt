# frozen_string_literal: true

require 'spec_helper'
require 'bolt/pal'
require 'bolt/pal/yaml_plan/evaluator'

describe Bolt::PAL::YamlPlan::Evaluator do
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

      plan = Bolt::PAL::YamlPlan::Loader.create(loader, plan_name, 'test.yaml', plan_body)

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

      plan = Bolt::PAL::YamlPlan::Loader.create(loader, plan_name, 'test.yaml', plan_body)

      expect(scope).not_to receive(:call_function)

      expect(call_plan(plan)).to eq(nil)
    end

    it 'fails if the steps list is not an array' do
      plan_body = <<-YAML
      steps: null
      YAML

      plan = Bolt::PAL::YamlPlan::Loader.create(loader, plan_name, 'test.yaml', plan_body)

      expect { call_plan(plan) }.to raise_error(Bolt::Error, /Plan must specify an array of steps/)
    end

    it 'fails if the steps list is not specified' do
      plan_body = <<-YAML
      parameters: {}
      YAML

      plan = Bolt::PAL::YamlPlan::Loader.create(loader, plan_name, 'test.yaml', plan_body)

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

      plan = Bolt::PAL::YamlPlan::Loader.create(loader, plan_name, 'test.yaml', plan_body)

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

      plan = Bolt::PAL::YamlPlan::Loader.create(loader, plan_name, 'test.yaml', plan_body)

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

      plan = Bolt::PAL::YamlPlan::Loader.create(loader, plan_name, 'test.yaml', plan_body)

      expect { call_plan(plan) }.to raise_error(Bolt::Error, /Unsupported plan step/)
    end

    it 'fails for an unknown step' do
      plan_body = <<-YAML
      steps:
        - package: openssl
          target: ["foo.example.com"]
      YAML

      plan = Bolt::PAL::YamlPlan::Loader.create(loader, plan_name, 'test.yaml', plan_body)

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

  describe "#script_step" do
    let(:step) do
      { 'script' => 'mymodule/myscript.sh',
        'target' => 'foo.example.com',
        'arguments' => %w[a b c] }
    end

    it 'fails if no target is specified' do
      step.delete('target')

      expect { subject.script_step(scope, step) }.to raise_error(/Can't run a script without specifying a target/)
    end

    it 'passes arguments to the script' do
      args = ['mymodule/myscript.sh', 'foo.example.com', 'arguments' => %w[a b c]]
      expect(scope).to receive(:call_function).with('run_script', args)

      subject.script_step(scope, step)
    end

    it 'succeeds if no arguments are specified' do
      step.delete('arguments')

      args = ['mymodule/myscript.sh', 'foo.example.com', 'arguments' => []]
      expect(scope).to receive(:call_function).with('run_script', args)

      subject.script_step(scope, step)
    end

    it 'succeeds if empty arguments are specified' do
      step['arguments'] = []

      args = ['mymodule/myscript.sh', 'foo.example.com', 'arguments' => []]
      expect(scope).to receive(:call_function).with('run_script', args)

      subject.script_step(scope, step)
    end

    it 'succeeds if nil arguments are specified' do
      step['arguments'] = nil

      args = ['mymodule/myscript.sh', 'foo.example.com', 'arguments' => []]
      expect(scope).to receive(:call_function).with('run_script', args)

      subject.script_step(scope, step)
    end

    it 'supports a description' do
      step['description'] = 'run the script'

      args = ['mymodule/myscript.sh', 'foo.example.com', 'run the script', 'arguments' => %w[a b c]]
      expect(scope).to receive(:call_function).with('run_script', args)

      subject.script_step(scope, step)
    end
  end

  describe "#eval_step" do
    let(:step) do
      { 'eval' => 55 }
    end

    it 'returns the result of the eval key' do
      expect(subject.eval_step(scope, step)). to eq(55)
    end
  end
end
