# frozen_string_literal: true

require 'bolt_spec/integration'
require 'bolt_spec/project'

describe 'managing a project' do
  include BoltSpec::Integration
  include BoltSpec::Project

  context 'creating a project' do
    let(:command) { %w[project init myproject --modules puppetlabs-yaml] }
    let(:project) { @project }

    # Execute from a temporary project directory.
    around(:each) do |example|
      in_project do |project|
        @project = project
        FileUtils.rm(project.project_file)
        example.run
      end
    end

    # Suppress output.
    before(:each) do
      allow($stdout).to receive(:puts)
      allow($stderr).to receive(:puts)
    end

    it 'creates a project and installs modules' do
      run_cli(command)

      expect(project.project_file.exist?).to be

      expect(YAML.load_file(project.project_file)).to include(
        'name'    => 'myproject',
        'modules' => [{ 'name' => 'puppetlabs-yaml' }]
      )

      expect(project.puppetfile.exist?).to be

      expect(File.read(project.puppetfile).lines).to include(
        /moduledir '.modules'/, %r{mod 'puppetlabs/yaml'}
      )

      expect(project.managed_moduledir.exist?).to be
    end
  end
end
