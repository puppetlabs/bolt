# frozen_string_literal: true

require 'spec_helper'
require 'bolt/pal/yaml_plan'

describe Bolt::PAL::YamlPlan::Step do
  context '#transpile' do
    let(:step_body) { {} }
    let(:step) { Bolt::PAL::YamlPlan::Step.create(step_body, 1) }

    def make_string(str)
      Bolt::PAL::YamlPlan::BareString.new(str)
    end

    shared_examples 'metaparameters' do
      it 'permits metaparameters under the parameters key' do
        step_body['parameters']['_catch_errors'] = true
        expect { step }.not_to raise_error
      end

      it 'permits top-level metaparameters keys' do
        step_body['catch_errors'] = true
        expect { step }.not_to raise_error
      end

      it 'errors with duplicate metaparameters under parameters key and top-level keys' do
        step_body['parameters']['_catch_errors'] = true
        step_body['catch_errors'] = true
        expect { step }.to raise_error(
          Bolt::PAL::YamlPlan::Step::StepError,
          /Cannot specify metaparameters when using top-level keys with same name: catch_errors/
        )
      end
    end

    context 'with message step' do
      let(:step_body) do
        {
          "message" => make_string("hello world")
        }
      end
      let(:output) { "  out::message('hello world')\n" }

      it 'stringifies a message step' do
        expect(step.transpile).to eq(output)
      end
    end

    context 'with command step' do
      let(:step_body) do
        { "command" => make_string("echo peanut butter"),
          "targets" => make_string("$bread") }
      end
      let(:output) { "  run_command('echo peanut butter', $bread)\n" }

      it 'stringifies a command step' do
        expect(step.transpile).to eq(output)
      end
    end

    context 'with script step' do
      let(:step_body) do
        { "script" => make_string("bananas.pb"),
          "targets" => make_string("$bread"),
          "arguments" => [make_string("--with cinnamon"), make_string("--and honey")] }
      end
      let(:output) { "  run_script('bananas.pb', $bread, {'arguments' => ['--with cinnamon', '--and honey']})\n" }

      it 'stringifies a script step' do
        expect(step.transpile).to eq(output)
      end
    end

    context 'with task step' do
      let(:step_body) do
        { "task" => make_string("jam::raspberry"),
          "targets" => make_string("$bread"),
          "description" => 'delicious',
          "parameters" => { "butter" => "crunchy peanut" } }
      end
      let(:output) {
        "  run_task('jam::raspberry', $bread, 'delicious',"\
                     " {'butter' => 'crunchy peanut'})\n"
      }

      include_examples 'metaparameters'

      it 'stringifies a task step' do
        expect(step.transpile).to eq(output)
      end
    end

    context 'with plan step' do
      let(:step_body) do
        { "plan" => make_string("sandwich::pbj"),
          "parameters" => { 'bread' => make_string("wheat") } }
      end
      let(:output) { "  run_plan('sandwich::pbj', {'bread' => 'wheat'})\n" }

      include_examples 'metaparameters'

      it 'stringifies a plan step' do
        expect(step.transpile).to eq(output)
      end
    end

    context 'with upload step' do
      let(:step_body) do
        { "upload" => make_string("lucys/kitchen/counter"),
          "destination" => make_string("/lucys/stomach"),
          "targets" => make_string("$sandwich") }
      end
      let(:output) { "  upload_file('lucys/kitchen/counter', '/lucys/stomach', $sandwich)\n" }

      it 'stringifies a upload step' do
        expect(step.transpile).to eq(output)
      end
    end

    context 'with download step' do
      let(:step_body) do
        {
          "download"    => make_string("/etc/ssh/ssh_config"),
          "destination" => make_string("downloads"),
          "targets"     => make_string("$foo")
        }
      end

      let(:output) { "  download_file('/etc/ssh/ssh_config', 'downloads', $foo)\n" }

      it 'stringifies a download step' do
        expect(step.transpile).to eq(output)
      end
    end

    context 'with eval step' do
      context "with barestring eval" do
        let(:step_body) do
          { "eval" => make_string("$count * 2") }
        end
        let(:output) { "  $count * 2\n" }

        it 'stringifies an eval step' do
          expect(step.transpile).to eq(output)
        end
      end

      context "with codeliteral eval" do
        let(:str) { <<~FOO }
        $list = $run_command.targets.map |$t| {
          notice($t)
          $t
        }
        $list
        FOO

        let(:step_body) do
          {
            "eval" => Bolt::PAL::YamlPlan::CodeLiteral.new(str),
            "name" => "eval_step"
          }
        end
        let(:output) { <<-OUT }
  $eval_step = with() || {
    $list = $run_command.targets.map |$t| {
      notice($t)
      $t
    }
    $list
  }
OUT

        it 'stringifies eval step' do
          expect(step.transpile).to eq(output)
        end
      end
    end

    context "with resources step" do
      let(:resources) do
        [{ 'package' => make_string('nginx') },
         { 'service' => make_string('nginx') }]
      end

      let(:step_body) do
        { 'resources' => resources,
          'targets' => make_string('$bread') }
      end

      context "#validate" do
        it 'fails if the resource type is ambiguous' do
          resources.replace([{ 'package' => 'nginx', 'service' => 'nginx' }])

          expect { Bolt::PAL::YamlPlan::Step::Resources.validate(step_body, 1) }
            .to raise_error(Bolt::Error, /Resource declaration has ambiguous type.*could be package or service/)
        end

        it 'fails if only type is set and not title' do
          resources.replace([{ 'type' => 'package' }])

          expect { Bolt::PAL::YamlPlan::Step::Resources.validate(step_body, 1) }
            .to raise_error(Bolt::Error, /Resource declaration must include title key if type key is set/)
        end

        it 'fails if only title is set and not type' do
          resources.replace([{ 'title' => 'hello world' }])

          expect { Bolt::PAL::YamlPlan::Step::Resources.validate(step_body, 1) }
            .to raise_error(Bolt::Error, /Resource declaration must include type key if title key is set/)
        end

        it 'fails if the resource has only parameters and no type or title' do
          resources.replace([{ 'parameters' => { 'ensure' => 'present' } }])

          expect { Bolt::PAL::YamlPlan::Step::Resources.validate(step_body, 1) }
            .to raise_error(Bolt::Error, /Resource declaration is missing a type/)
        end

        it 'fails if the resource is empty' do
          resources.replace([{}])

          expect { Bolt::PAL::YamlPlan::Step::Resources.validate(step_body, 1) }
            .to raise_error(Bolt::Error, /Resource declaration is missing a type/)
        end
      end

      context "normalizing resources" do
        it 'uses the type and title keys if specified' do
          expected = [{ 'type' => 'package', 'title' => make_string('nginx'), 'parameters' => {} },
                      { 'type' => 'service', 'title' => make_string('nginx'), 'parameters' => {} }]

          expect(step.body['resources']).to eq(expected)
        end
      end

      context "transpiling" do
        it "generates an apply() block" do
          output = <<-OUT
  apply_prep($bread)
  apply($bread) {
    package { 'nginx': }
    ->
    service { 'nginx': }
  }
          OUT

          expect(step.transpile).to eq(output)
        end

        it "generates an empty apply() block if no resources are declared" do
          resources.replace([])

          output = <<-OUT
  apply_prep($bread)
  apply($bread) {

  }
          OUT

          expect(step.transpile).to eq(output)
        end

        it "assigns the result of the apply() block to a variable if the step is named" do
          step_body['name'] = 'test_apply'

          output = <<-OUT
  apply_prep($bread)
  $test_apply = apply($bread) {
    package { 'nginx': }
    ->
    service { 'nginx': }
  }
          OUT

          expect(step.transpile).to eq(output)
        end

        it "passes resource parameters if they're set" do
          resources.replace([{ 'package' => 'nginx', 'parameters' => { 'ensure' => 'latest' } },
                             { 'service' => 'nginx', 'parameters' => { 'ensure' => 'running', 'enable' => true } }])

          output = <<-OUT
  apply_prep($bread)
  apply($bread) {
    package { 'nginx':
      ensure => 'latest',
    }
    ->
    service { 'nginx':
      ensure => 'running',
      enable => true,
    }
  }
          OUT

          expect(step.transpile).to eq(output)
        end
      end
    end

    context "with string parameters key" do
      let(:step_body) do
        { "task" => make_string("jam::raspberry"),
          "targets" => make_string("$bread"),
          "description" => 'delicious',
          "parameters" => "deceptive peanut butter" }
      end

      it "raises an error" do
        expect { step.transpile }
          .to raise_error(Bolt::Error, /Parameters key must be a hash/)
      end
    end
  end
end
