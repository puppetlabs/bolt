# frozen_string_literal: true

require 'spec_helper'
require 'bolt/pal'
require 'bolt/pal/yaml_plan/loader'

describe Bolt::PAL::YamlPlan::Loader do
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

  describe "::create" do
    it 'fails if the plan is not a Hash' do
      plan_body = '[]'

      expect { described_class.create(loader, plan_name, 'test.yaml', plan_body) }.to raise_error(
        ArgumentError, /test.yaml does not contain an object/
      )
    end

    it 'fails if step key points to bad puppet code' do
      plan_body = <<-YAML
      steps:
        - command: $
          target: foo
      YAML

      expect { described_class.create(loader, plan_name, 'test.yaml', plan_body) }.to raise_error do |error|
        expect(error.to_s).to match(/Parse error in step number 1/)
        expect(error.to_s).to match(/Error parsing \"command\": Illegal variable name/)
      end
    end

    it 'returns a puppet function wrapper' do
      plan_body = <<-YAML
      steps: []
      YAML

      plan = described_class.create(loader, plan_name, 'test.yaml', plan_body)
      expect(plan).to be_a(Puppet::Functions::Function)
    end
  end
end
