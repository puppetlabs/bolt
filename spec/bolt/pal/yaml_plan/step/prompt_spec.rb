# frozen_string_literal: true

require 'spec_helper'
require 'bolt/pal/yaml_plan'

describe Bolt::PAL::YamlPlan::Step::Prompt do
  let(:evaluator) { double('evaluator') }
  let(:scope)     { double('scope', call_function: nil) }
  let(:step)      { Bolt::PAL::YamlPlan::Step.create(body, 0) }

  context 'without menu' do
    let(:body) do
      {
        'prompt'    => 'What is your favorite color',
        'default'   => 'blue',
        'sensitive' => true
      }
    end

    it 'creates a step class' do
      expect(step).to be_kind_of(described_class)
    end

    it 'evaluates prompt function' do
      allow(evaluator).to receive(:evaluate_code_blocks).and_return(body)

      args = ['What is your favorite color', { 'default' => 'blue', 'sensitive' => true }]
      expect(scope).to receive(:call_function).with('prompt', args)

      step.evaluate(scope, evaluator)
    end

    it 'transpiles prompt function' do
      expect(step.transpile)
        .to eq("  prompt('What is your favorite color', {'default' => 'blue', 'sensitive' => true})\n")
    end
  end

  context 'with menu' do
    let(:body) do
      {
        'prompt'  => 'Select a fruit',
        'menu'    => %w[apple banana carrot],
        'default' => 'apple'
      }
    end

    it 'creates a step class' do
      expect(step).to be_kind_of(described_class)
    end

    it 'errors if menu is not an array or hash' do
      body['menu'] = false
      expect { step }.to raise_error(/Menu key must be an array or hash/)
    end

    it 'evaluates prompt::menu function' do
      allow(evaluator).to receive(:evaluate_code_blocks).and_return(body)

      args = ['Select a fruit', %w[apple banana carrot], { 'default' => 'apple' }]
      expect(scope).to receive(:call_function).with('prompt::menu', args)

      step.evaluate(scope, evaluator)
    end

    it 'transpiles prompt::menu function' do
      expect(step.transpile)
        .to eq("  prompt::menu('Select a fruit', ['apple', 'banana', 'carrot'], {'default' => 'apple'})\n")
    end
  end
end
