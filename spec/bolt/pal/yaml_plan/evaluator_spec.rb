# frozen_string_literal: true

require 'spec_helper'
require 'bolt/pal'
require 'bolt/pal/yaml_plan/evaluator'

describe Bolt::PAL::YamlPlan::Evaluator do
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
    let(:plan) { Bolt::PAL::YamlPlan::Loader.create(loader, plan_name, 'test.yaml', @plan_body) }

    it 'validates the parameters' do
      @plan_body = <<-YAML
      parameters:
        foo:
          type: String
        bar:
          type: Integer

      steps: []
      YAML

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
      @plan_body = <<-YAML
      steps: []
      YAML

      expect(scope).not_to receive(:call_function)

      expect(call_plan(plan)).to eq(nil)
    end

    it 'runs each step in order' do
      @plan_body = <<-YAML
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

      nodes = %w[foo.example.com bar.example.com]
      params = { 'action' => 'status', 'name' => 'openssl' }
      expect(scope).to receive(:call_function).with('run_task', ['package', nodes, params]).ordered
      expect(scope).to receive(:call_function).with('run_command', ['hostname -f', nodes]).ordered

      call_plan(plan, 'package' => 'openssl', 'nodes' => nodes)
    end

    it 'can be run multiple times with different parameters' do
      @plan_body = <<-YAML
      parameters:
        nodes:
          type: TargetSpec
      steps:
        - command: hostname -f
          target: $nodes
      YAML

      expect(scope).to receive(:call_function).with('run_command', ['hostname -f', ['foo.example.com']])
      call_plan(plan, 'nodes' => ['foo.example.com'])

      expect(scope).to receive(:call_function).with('run_command', ['hostname -f', ['bar.example.com']])
      call_plan(plan, 'nodes' => ['bar.example.com'])
    end

    it 'returns the `return` value on completion' do
      @plan_body = <<-YAML
      steps: []
      return: "hello world"
      YAML

      expect(call_plan(plan)).to eq('hello world')
    end

    it 'accepts an expression for the `return` value' do
      @plan_body = <<-YAML
      parameters:
        foo:
          type: String
      steps: []
      return: $foo
      YAML

      expect(call_plan(plan, 'foo' => 'hello world')).to eq('hello world')
    end

    it 'accepts an object for the `return` value' do
      @plan_body = <<-YAML
      steps: []
      return: [1, 2, 3, 4, 5]
      YAML

      expect(call_plan(plan)).to eq([1, 2, 3, 4, 5])
    end

    it 'accepts an array of expressions for the `return` value' do
      @plan_body = <<-YAML
      parameters:
        n:
          type: Integer
      steps: []
      return:
        - $n
        - $n * 2
        - $n + 5
      YAML

      expect(call_plan(plan, 'n' => 7)).to eq([7, 14, 12])
    end

    it 'can reference step results in the `return` expression' do
      @plan_body = <<-YAML
      parameters:
        n:
          type: Integer
      steps:
        - name: first
          eval: $n * 2
        - name: second
          eval: $first * 3
      return: [ $n, $first, $second ]
      YAML

      expect(call_plan(plan, 'n' => 3)).to eq([3, 6, 18])
    end

    it 'returns undef if the plan has no `return` expression' do
      @plan_body = <<-YAML
      steps: []
      YAML

      expect(call_plan(plan)).to be_nil
    end
  end

  describe "#task_step" do
    let(:step) do
      { 'task' => 'package',
        'target' => 'foo.example.com',
        'parameters' => { 'action' => 'status',
                          'name' => 'openssl' } }
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

  describe "#plan_step" do
    let(:step) do
      { 'plan' => 'testplan',
        'parameters' => { 'message' => 'hello',
                          'count' => 5 } }
    end

    it 'passes parameters to the plan' do
      expect(scope).to receive(:call_function).with('run_plan', ['testplan', { 'message' => 'hello', 'count' => 5 }])

      subject.plan_step(scope, step)
    end

    it 'succeeds if no parameters are specified' do
      step.delete('parameters')

      expect(scope).to receive(:call_function).with('run_plan', ['testplan', {}])

      subject.plan_step(scope, step)
    end
    it 'succeeds if nil parameters are specified' do
      step['parameters'] = nil

      expect(scope).to receive(:call_function).with('run_plan', ['testplan', {}])

      subject.plan_step(scope, step)
    end
  end

  describe "#command_step" do
    let(:step) do
      { 'command' => 'hostname -f',
        'target' => 'foo.example.com' }
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

  describe "#upload_step" do
    let(:step) do
      { 'source' => 'mymodule/file.txt',
        'destination' => '/path/to/file.txt',
        'target' => 'foo.example.com' }
    end

    it 'uploads the file' do
      args = ['mymodule/file.txt', '/path/to/file.txt', 'foo.example.com']
      expect(scope).to receive(:call_function).with('upload_file', args)

      subject.upload_step(scope, step)
    end

    it 'supports a description' do
      step['description'] = 'upload the file'

      args = ['mymodule/file.txt', '/path/to/file.txt', 'foo.example.com', 'upload the file']
      expect(scope).to receive(:call_function).with('upload_file', args)

      subject.upload_step(scope, step)
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

  describe "#resources_step" do
    let(:step) do
      { 'resources' => resources,
        'target' => target }
    end
    let(:resources) do
      [{ 'package' => 'nginx' },
       { 'service' => 'nginx' }]
    end
    let(:target) { ['foo.example.com', 'bar.example.com'] }
    let(:applicator) { double('applicator') }

    before :each do
      allow(subject).to receive(:apply_manifest)
    end

    around :each do |example|
      begin
        Puppet.push_context(apply_executor: applicator)
        example.run
      ensure
        Puppet.pop_context
      end
    end

    it 'builds and applies a manifest' do
      # We need to normalize the resources by creating a step instance
      step_body = Bolt::PAL::YamlPlan::Step::Resources.new(step).body

      expected = [{ 'type' => 'package', 'title' => 'nginx', 'parameters' => {} },
                  { 'type' => 'service', 'title' => 'nginx', 'parameters' => {} }]

      expect(subject).to receive(:generate_manifest).with(expected).and_return('mymanifest')
      expect(subject).to receive(:apply_manifest).with(scope, target, 'mymanifest')

      subject.resources_step(scope, step_body)
    end

    it 'succeeds if no resources are specified' do
      resources.replace([])

      expect(subject).to receive(:generate_manifest).with([])

      subject.resources_step(scope, step)
    end
  end

  describe "referring to previous steps" do
    let(:plan) { Bolt::PAL::YamlPlan::Loader.create(loader, plan_name, 'test.yaml', @plan_body) }

    it "stores the result of a step in a variable" do
      @plan_body = <<-YAML
      parameters:
        input:
          type: Integer

      steps:
        - name: foo
          eval: $input + 5
        - name: bar
          command: "echo ${$foo*2}"
          target: foo.example.com
      YAML

      expect(scope).to receive(:call_function).with('run_command', ['echo 34', 'foo.example.com'])

      call_plan(plan, 'input' => 12)
    end

    it "accepts a step without a name" do
      @plan_body = <<-YAML
      steps:
        - eval: >
            5+6
      YAML

      call_plan(plan)
    end

    it "can store and retrieve 'undef' results" do
      @plan_body = <<-YAML
      steps:
        - name: foo
          eval: >
            undef
        - name: bar
          eval: $foo
      YAML

      call_plan(plan)
    end
  end
end
