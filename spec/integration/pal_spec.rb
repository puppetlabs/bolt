# frozen_string_literal: true

require 'spec_helper'

require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/project'
require 'bolt_spec/pal'

describe Bolt::PAL do
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::Project
  include BoltSpec::PAL

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

  describe :show_module do
    let(:metadata)   { JSON.parse(File.read(fixtures_path('modules', 'sample', 'metadata.json'))) }
    let(:modulepath) { Bolt::Config::Modulepath.new([fixtures_path('modules')]) }
    let(:pal)        { Bolt::PAL.new(modulepath, nil, nil) }

    it 'accepts short name' do
      allow(pal).to receive_messages(list_plans_with_cache: [], list_tasks_with_cache: [])
      expect { pal.show_module('sample') }.not_to raise_error
    end

    it 'accepts forge name with /' do
      allow(pal).to receive_messages(list_plans_with_cache: [], list_tasks_with_cache: [])
      expect { pal.show_module('bolt/sample') }.not_to raise_error
    end

    it 'accepts forge name with -' do
      allow(pal).to receive_messages(list_plans_with_cache: [], list_tasks_with_cache: [])
      expect { pal.show_module('bolt-sample') }.not_to raise_error
    end

    it 'errors with unknown module' do
      expect { pal.show_module('abcdefg') }.to raise_error(
        Bolt::Error,
        /Could not find module 'abcdefg' on the modulepath/
      )
    end

    it 'returns expected data' do
      result = pal.show_module('bolt/sample')

      expect(result.keys).to match_array(%i[metadata name path plans tasks]),
                             'Does not return expected keys'

      expect(result[:name]).to eq('bolt/sample'),
                               'Does not return Forge name'

      expect(result[:path]).to eq(fixtures_path('modules', 'sample')),
                               'Does not return path to module'

      expect(result[:plans]).to include(
        ['sample::single_task', 'one line plan to show we can run a task by name'],
        ['sample::yaml', nil]
      ),
                                'Does not return plan list'

      expect(result[:tasks]).to include(
        ['sample::multiline', 'Write a multiline string to the console']
      ),
                                'Does not return task list'

      expect(result[:metadata]).to match(metadata),
                                   'Does not return metadata'
    end
  end
end
