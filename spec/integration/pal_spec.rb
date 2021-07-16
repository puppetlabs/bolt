# frozen_string_literal: true

require 'spec_helper'

require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/project'

describe Bolt::PAL do
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::Project

  describe :show_module do
    around(:each) do |example|
      with_project(config: config) do |project|
        @project = project
        example.run
      end
    end

    let(:config)     { { 'modulepath' => [modulepath] } }
    let(:modulepath) { fixtures_path('modules') }
    let(:outputter)  { Bolt::Outputter::Human }
    let(:project)    { @project }

    it 'prints module information' do
      result = run_cli(%w[module show sample], outputter: outputter, project: project)
      expect(result).to match(%r{bolt/sample \[1.0.0\]}m)
    end
  end
end
