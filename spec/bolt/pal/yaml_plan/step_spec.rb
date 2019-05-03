# frozen_string_literal: true

require 'spec_helper'
require 'bolt/pal/yaml_plan'

describe Bolt::PAL::YamlPlan::Step do
  context '#transpile' do
    let(:step_body) { {} }
    let(:step) { Bolt::PAL::YamlPlan::Step.new(step_body, 1) }

    def make_string(str)
      Bolt::PAL::YamlPlan::BareString.new(str)
    end

    context 'with command step' do
      let(:step_body) do
        { "command" => make_string("echo peanut butter"),
          "target" => make_string("$bread") }
      end
      let(:output) { "  run_command('echo peanut butter', $bread)\n" }

      it 'stringifies a command step' do
        expect(step.transpile('/path/to/happiness')).to eq(output)
      end
    end

    context 'with script step' do
      let(:step_body) do
        { "script" => make_string("bananas.pb"),
          "target" => make_string("$bread"),
          "arguments" => [make_string("--with cinnamon"), make_string("--and honey")] }
      end
      let(:output) { "  run_script('bananas.pb', $bread, {'arguments' => ['--with cinnamon', '--and honey']})\n" }

      it 'stringifies a script step' do
        expect(step.transpile('/path/to/happiness')).to eq(output)
      end
    end

    context 'with task step' do
      let(:step_body) do
        { "task" => make_string("jam::raspberry"),
          "target" => make_string("$bread"),
          "description" => 'delicious',
          "parameters" => { "butter" => "crunchy peanut" } }
      end
      let(:output) {
        "  run_task('jam::raspberry', $bread, 'delicious',"\
                     " {'butter' => 'crunchy peanut'})\n"
      }

      it 'stringifies a task step' do
        expect(step.transpile('/path/to/happiness')).to eq(output)
      end
    end

    context 'with plan step' do
      let(:step_body) do
        { "plan" => make_string("sandwich::pbj"),
          "target" => make_string("$bread"),
          "parameters" => {} }
      end
      let(:output) { "  run_plan('sandwich::pbj', $bread)\n" }

      it 'stringifies a plan step' do
        expect(step.transpile('/path/to/happiness')).to eq(output)
      end
    end

    context 'with upload step' do
      let(:step_body) do
        { "source" => make_string("lucys/kitchen/counter"),
          "destination" => make_string("/lucys/stomach"),
          "target" => make_string("$sandwich") }
      end
      let(:output) { "  upload_file('lucys/kitchen/counter', '/lucys/stomach', $sandwich)\n" }

      it 'stringifies a upload step' do
        expect(step.transpile('/path/to/happiness')).to eq(output)
      end
    end

    context 'with eval step' do
      context "with barestring eval" do
        let(:step_body) do
          { "eval" => make_string("$count * 2") }
        end
        let(:output) { "  $count * 2\n" }

        it 'stringifies an eval step' do
          expect(step.transpile('/path/to/happiness')).to eq(output)
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
          expect(step.transpile('/path/to/happiness')).to eq(output)
        end
      end
    end

    context "with string parameters key" do
      let(:step_body) do
        { "task" => make_string("jam::raspberry"),
          "target" => make_string("$bread"),
          "description" => 'delicious',
          "parameters" => "deceptive peanut butter" }
      end

      it "raises an error" do
        expect { step.transpile('/path/to/happiness') }
          .to raise_error(Bolt::Error, /Parameters key must be a hash/)
      end
    end
  end
end
