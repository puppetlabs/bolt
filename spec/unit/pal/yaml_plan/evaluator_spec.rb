# frozen_string_literal: true

require 'spec_helper'
require 'bolt/pal'
require 'bolt/pal/yaml_plan/evaluator'
require 'bolt/target'

describe Bolt::PAL::YamlPlan::Evaluator do
  let(:plan_name) { Puppet::Pops::Loader::TypedName.new(:plan, 'test') }
  let(:pal) { Bolt::PAL.new(Bolt::Config::Modulepath.new([]), nil, nil) }
  # It doesn't really matter which loader or scope we use, but we need them, so take the
  # static loader and global scope
  let(:loader) { Puppet.lookup(:loaders).static_loader }
  let(:scope) { Puppet.lookup(:global_scope) }
  let(:step) { Bolt::PAL::YamlPlan::Step.create(step_body, 1) }

  around :each do |example|
    pal.in_bolt_compiler do
      example.run
    end
  end

  before :each do
    # Make sure we don't accidentally call any run functions
    allow(scope).to receive(:call_function)
    allow_any_instance_of(Bolt::Analytics::NoopClient).to receive(:event)
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
          targets: $nodes
          parameters:
            action: status
            name: $package
        - command: hostname -f
          targets: $nodes
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
          targets: $nodes
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

  describe "message step" do
    let(:step_body) do
      {
        'message' => 'hello world'
      }
    end

    it 'calls out::message' do
      expect(scope).to receive(:call_function).with('out::message', ['hello world'])
      step.evaluate(scope, subject)
    end
  end

  describe "verbose step" do
    let(:step_body) do
      {
        'verbose' => 'hello world'
      }
    end

    it 'calls out::verbose' do
      expect(scope).to receive(:call_function).with('out::verbose', ['hello world'])
      step.evaluate(scope, subject)
    end
  end

  describe "task step" do
    let(:step_body) do
      { 'task' => 'package',
        'targets' => 'foo.example.com',
        'parameters' => { 'action' => 'status',
                          'name' => 'openssl' } }
    end

    it 'succeeds if no parameters are specified' do
      step_body.delete('parameters')

      expect(scope).to receive(:call_function).with('run_task', ['package', 'foo.example.com'])
      step.evaluate(scope, subject)
    end

    it 'succeeds if empty parameters are specified' do
      step_body['parameters'] = {}

      expect(scope).to receive(:call_function).with('run_task', ['package', 'foo.example.com'])
      step.evaluate(scope, subject)
    end

    it 'supports a description' do
      step_body['description'] = 'run the thing'

      args = ['package', 'foo.example.com', 'run the thing', { 'action' => 'status', 'name' => 'openssl' }]
      expect(scope).to receive(:call_function).with('run_task', args)

      step.evaluate(scope, subject)
    end
  end

  describe "plan step" do
    let(:step_body) do
      { 'plan' => 'testplan',
        'parameters' => { 'message' => 'hello',
                          'count' => 5 } }
    end

    it 'passes parameters to the plan' do
      expect(scope).to receive(:call_function).with('run_plan', ['testplan', { 'message' => 'hello', 'count' => 5 }])

      step.evaluate(scope, subject)
    end

    it 'succeeds if no parameters are specified' do
      step_body.delete('parameters')

      expect(scope).to receive(:call_function).with('run_plan', ['testplan'])

      step.evaluate(scope, subject)
    end

    it 'succeeds if empty parameters are specified' do
      step_body['parameters'] = {}

      expect(scope).to receive(:call_function).with('run_plan', ['testplan'])

      step.evaluate(scope, subject)
    end
  end

  describe "command step" do
    let(:step_body) do
      { 'command' => 'hostname -f',
        'targets' => 'foo.example.com' }
    end

    it 'supports a description' do
      step_body['description'] = 'run the thing'

      expect(scope).to receive(:call_function).with('run_command', ['hostname -f', 'foo.example.com', 'run the thing'])
      step.evaluate(scope, subject)
    end
  end

  describe "script step" do
    let(:step_body) do
      { 'script' => 'mymodule/myscript.sh',
        'targets' => 'foo.example.com',
        'arguments' => %w[a b c] }
    end

    context 'with arguments' do
      it 'passes arguments to the script' do
        args = ['mymodule/myscript.sh', 'foo.example.com', 'arguments' => %w[a b c]]
        expect(scope).to receive(:call_function).with('run_script', args)

        step.evaluate(scope, subject)
      end

      it 'succeeds if no arguments are specified' do
        step_body.delete('arguments')

        args = ['mymodule/myscript.sh', 'foo.example.com']
        expect(scope).to receive(:call_function).with('run_script', args)

        step.evaluate(scope, subject)
      end

      it 'succeeds if empty arguments are specified' do
        step_body['arguments'] = []

        args = ['mymodule/myscript.sh', 'foo.example.com']
        expect(scope).to receive(:call_function).with('run_script', args)

        step.evaluate(scope, subject)
      end

      it 'succeeds if nil arguments are specified' do
        step_body['arguments'] = nil

        args = ['mymodule/myscript.sh', 'foo.example.com']
        expect(scope).to receive(:call_function).with('run_script', args)

        step.evaluate(scope, subject)
      end

      it 'errors if arguments is not an array' do
        step_body['arguments'] = { 'foo' => 'bar' }

        expect { step }.to raise_error(/arguments key must be an array/)
      end
    end

    context 'with pwsh_params' do
      let(:params) { { 'Name' => 'BoltyMcBoltface' } }
      let(:script) { 'mymodule/myscript.sh' }
      let(:target) { 'foo.example.com' }

      let(:step_body) do
        {
          'script'      => script,
          'targets'     => target,
          'pwsh_params' => params
        }
      end

      it 'passes pwsh_params to the script' do
        args = [script, target, { 'pwsh_params' => params }]

        expect(scope).to receive(:call_function).with('run_script', args)
        step.evaluate(scope, subject)
      end

      it 'succeeds if empty pwsh_params are specified' do
        step_body['pwsh_params'] = {}
        args = [script, target]

        expect(scope).to receive(:call_function).with('run_script', args)
        step.evaluate(scope, subject)
      end

      it 'succeeds if nil pwsh_params are specified' do
        step_body['pwsh_params'] = nil
        args = [script, target]

        expect(scope).to receive(:call_function).with('run_script', args)
        step.evaluate(scope, subject)
      end

      it 'errors if pwsh_params is not a hash' do
        step_body['pwsh_params'] = ['-Name', 'foo']

        expect { step }.to raise_error(/pwsh_params key must be a hash/)
      end
    end

    it 'supports a description' do
      step_body['description'] = 'run the script'

      args = ['mymodule/myscript.sh', 'foo.example.com', 'run the script', 'arguments' => %w[a b c]]
      expect(scope).to receive(:call_function).with('run_script', args)

      step.evaluate(scope, subject)
    end
  end

  describe "upload step" do
    let(:step_body) do
      { 'upload' => 'mymodule/file.txt',
        'destination' => '/path/to/file.txt',
        'targets' => 'foo.example.com' }
    end

    it 'uploads the file' do
      args = ['mymodule/file.txt', '/path/to/file.txt', 'foo.example.com']
      expect(scope).to receive(:call_function).with('upload_file', args)

      step.evaluate(scope, subject)
    end

    it 'supports a description' do
      step_body['description'] = 'upload the file'

      args = ['mymodule/file.txt', '/path/to/file.txt', 'foo.example.com', 'upload the file']
      expect(scope).to receive(:call_function).with('upload_file', args)

      step.evaluate(scope, subject)
    end
  end

  describe "download step" do
    let(:source)      { '/etc/ssh/ssh_config' }
    let(:destination) { 'downloads' }
    let(:target)      { 'foo.example.com' }

    let(:step_body) do
      {
        'download'    => source,
        'destination' => destination,
        'targets'     => target
      }
    end

    it 'downloads the file' do
      args = [source, destination, target]
      expect(scope).to receive(:call_function).with('download_file', args)

      step.evaluate(scope, subject)
    end

    it 'supports a description' do
      step_body['description'] = 'download the file'

      args = [source, destination, target, 'download the file']
      expect(scope).to receive(:call_function).with('download_file', args)

      step.evaluate(scope, subject)
    end
  end

  describe "eval step" do
    let(:step_body) do
      { 'eval' => 55 }
    end

    it 'returns the result of the eval key' do
      expect(step.evaluate(scope, subject)).to eq(55)
    end
  end

  describe "resources step" do
    let(:step_body) do
      { 'resources' => resources,
        'targets' => target }
    end
    let(:resources) do
      [{ 'package' => 'nginx' },
       { 'service' => 'nginx' }]
    end
    let(:target) { ['foo.example.com', 'bar.example.com'] }
    let(:applicator) { double('applicator') }

    around :each do |example|
      Puppet.push_context(apply_executor: applicator)
      example.run
    ensure
      Puppet.pop_context
    end

    it 'builds and applies a manifest' do
      expected = [{ 'type' => 'package', 'title' => 'nginx', 'parameters' => {} },
                  { 'type' => 'service', 'title' => 'nginx', 'parameters' => {} }]

      allow(step).to receive(:apply_manifest)
      expect(step).to receive(:generate_manifest).with(expected).and_return('mymanifest')
      expect(step).to receive(:apply_manifest).with(scope, [target], 'mymanifest')

      step.evaluate(scope, subject)
    end

    it 'succeeds if no resources are specified' do
      resources.replace([])

      allow(step).to receive(:apply_manifest)
      expect(step).to receive(:generate_manifest).with([])

      step.evaluate(scope, subject)
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
          targets: foo.example.com
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
