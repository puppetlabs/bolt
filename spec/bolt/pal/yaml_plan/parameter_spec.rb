# frozen_string_literal: true

require 'spec_helper'
require 'bolt/pal/yaml_plan/parameter'

describe Bolt::PAL::YamlPlan::Parameter do
  context '#transpile' do
    let(:str_type) { 'String' }
    let(:int_type) { 'Integer' }

    let(:name) { 'myvar' }
    let(:value) { nil }
    let(:type) { nil }
    let(:definition) do
      { 'default' => value,
        'type' => type }
    end

    let(:param) { Bolt::PAL::YamlPlan::Parameter.new(name, definition) }

    context 'with a defined type' do
      let(:type) { str_type }

      it 'transpiles with a type' do
        expect(param.transpile).to eq("\n  String $myvar")
      end
    end

    it 'transpiles with no type' do
      expect(param.transpile).to eq("\n  $myvar")
    end

    context 'with a default string' do
      let(:value) { 'Default' }
      let(:type) { str_type }

      it 'transpiles a parameter with a default' do
        expect(param.transpile).to eq("\n  String $myvar = 'Default'")
      end
    end

    context 'with a default non-string' do
      let(:value) { 3 }
      let(:type) { int_type }

      it 'transpiles a parameter with a default' do
        expect(param.transpile).to eq("\n  Integer $myvar = 3")
      end
    end
  end
end
