# frozen_string_literal: true

require 'spec_helper'
require 'bolt/plan_creator'
require 'bolt_spec/project'

describe Bolt::PlanCreator do
  include BoltSpec::Project

  let(:project)   { @project }
  let(:plan_name) { 'project' }

  around :each do |example|
    with_project(plan_name) do |project|
      @project = project
      example.run
    end
  end

  context "#validate_plan_name" do
    it 'errors without a named project' do
      allow(project).to receive(:name).and_return(nil)
      expect { subject.validate_plan_name(project, plan_name) }.to raise_error(
        Bolt::Error,
        /Project directory '.*' is not a named project/
      )
    end

    it 'errors when the plan name is invalid' do
      %w[Foo foo-bar foo:: foo::Bar foo::1bar ::foo].each do |plan_name|
        expect { subject.validate_plan_name(project, plan_name) }.to raise_error(
          Bolt::ValidationError,
          /Invalid plan name '#{plan_name}'/
        )
      end
    end

    it 'errors if the first name segment is not the project name' do
      expect { subject.validate_plan_name(project, 'plan') }.to raise_error(
        Bolt::ValidationError,
        /Incomplete plan name: A plan name must be prefixed with the name of the/
      )
    end

    %w[pp yaml].each do |ext|
      it "errors if there is an existing #{ext} plan with the same name" do
        plan_path = File.join(project.path, 'plans', "init.#{ext}")
        FileUtils.mkdir(File.dirname(plan_path))
        FileUtils.touch(plan_path)

        expect { subject.validate_plan_name(project, plan_name) }.to raise_error(
          Bolt::Error,
          /A plan with the name '#{plan_name}' already exists/
        )
      end
    end
  end

  context "#create_plan" do
    it "creates a missing 'plans' directory" do
      expect(Dir.exist?(project.plans_path)).to eq(false)
      subject.create_plan(project.plans_path, plan_name)
      expect(Dir.exist?(project.plans_path)).to eq(true)
    end

    it 'creates a missing directory structure' do
      plan_name = "#{project.name}::foo::bar"
      expect(Dir.exist?(project.plans_path + 'foo')).to eq(false)
      subject.create_plan(project.plans_path, plan_name)
      expect(Dir.exist?(project.plans_path + 'foo')).to eq(true)
    end

    it 'catches existing file errors when creating directories' do
      plan_name = "#{project.name}::foo::bar"
      FileUtils.mkdir(project.plans_path)
      FileUtils.touch(project.plans_path + 'foo')

      expect { subject.create_plan(project.plans_path, plan_name) }
        .to raise_error(Bolt::Error, /unable to create plan directory/)
    end

    it "creates an 'init' plan when the plan name matches the project name" do
      subject.create_plan(project.plans_path, plan_name)
      expect(File.exist?(project.plans_path + 'init.yaml')).to eq(true)
    end

    it 'creates a yaml plan by default' do
      plan_name = "#{project.name}::foo"

      subject.create_plan(project.plans_path, plan_name)
      expect(File.read(project.plans_path + 'foo.yaml'))
        .to eq(subject.send(:yaml_plan, plan_name))
    end

    it 'creates a puppet plan when the flag is provided' do
      plan_name = "#{project.name}::foo"

      subject.create_plan(project.plans_path, plan_name, is_puppet: true)
      expect(File.read(project.plans_path + 'foo.pp'))
        .to eq(subject.send(:puppet_plan, plan_name))
    end

    context "with --script" do
      let(:script) { 'mymodule/scripts/chillout.ps1' }

      it 'creates a yaml plan that runs the provided script' do
        plan_name = "#{project.name}::foo"

        subject.create_plan(project.plans_path, plan_name, script: script)
        expect(File.read(project.plans_path + 'foo.yaml'))
          .to eq(subject.send(:yaml_script_plan, script))
      end

      it 'creates a puppet plan that runs the script' do
        plan_name = "#{project.name}::foo"

        subject.create_plan(project.plans_path, plan_name, is_puppet: true, script: script)
        expect(File.read(project.plans_path + 'foo.pp'))
          .to eq(subject.send(:puppet_script_plan, plan_name, script))
      end
    end

    it 'returns the name and path to the plan' do
      expect(subject.create_plan(project.plans_path, plan_name)).to include(
        name: plan_name,
        path: project.plans_path + 'init.yaml'
      )
    end
  end
end
