# frozen_string_literal: true

require 'spec_helper'
require 'bolt/project'
require 'bolt_spec/project'

describe Bolt::Project do
  include BoltSpec::Project

  it "loads from system-wide config path if homedir expansion fails" do
    allow(File).to receive(:expand_path).and_call_original
    allow(File)
      .to receive(:expand_path)
      .with(File.join('~', '.puppetlabs', 'bolt'))
      .and_raise(ArgumentError, "couldn't find login name -- expanding `~'")
    project = Bolt::Project.default_project
    # we have to call expand_path to ensure C:/ instead of C:\ on Windows
    expect(project.path.to_s).to eq(File.expand_path(Bolt::Config.system_path))
  end

  describe "configuration" do
    let(:project_config) { { 'tasks' => ['facts'] } }

    around(:each) do |example|
      with_project do
        example.run
      end
    end

    it "loads config with defaults" do
      expect(project.tasks).to eq(project_config['tasks'])
      expect(project.plans).to eq(nil)
    end

    context 'with bolt config values' do
      let(:project_config) {
        {
          'concurrency' => 20,
          'transport' => 'ssh',
          'ssh' => {
            'user' => 'blueberry'
          }
        }
      }

      it 'loads config' do
        expect(project.data['concurrency']).to eq(20)
      end

      it "ignores transport config" do
        expect(project.data.key?('ssh')).to be false
        expect(project.data.key?('transport')).to be false
      end
    end

    describe "with modules specified as strings and hashes" do
      let(:project_config) {
        { 'modules' => [
          'puppetlabs-yaml',
          { 'name' => 'puppetlabs-apache' }
        ] }
      }

      it 'accepts string and hash input, and normalizes' do
        expect(project.modules).to eq([{ "name" => "puppetlabs-yaml" }, { "name" => "puppetlabs-apache" }])
      end
    end

    describe "with invalid name config" do
      let(:project_config) { { 'name' => '_invalid' } }

      it "raises an error" do
        expect { project.validate }.to raise_error(/Invalid project name '_invalid' in bolt-project.yaml/)
      end
    end

    describe "with namespaced project names" do
      let(:project_config) { { 'name' => 'puppetlabs-foo' } }

      it "raises an error" do
        expect { project.validate }.to raise_error(/Invalid project name 'puppetlabs-foo' in bolt-project.yaml/)
      end
    end
  end

  describe "::find_boltdir" do
    around(:each) do |example|
      with_boltdir do
        example.run
      end
    end

    describe "when the project directory is named Boltdir" do
      it 'finds project from inside project' do
        expect(Bolt::Project.find_boltdir(project_path)).to eq(project)
      end

      it 'finds project from the parent directory' do
        expect(Bolt::Project.find_boltdir(project_path.parent)).to eq(project)
      end

      it 'does not find project from the grandparent directory' do
        expect(Bolt::Project.find_boltdir(project_path.parent.parent)).not_to eq(project)
      end

      it 'finds the project from a sibling directory' do
        sibling = project_path.parent + 'bar'
        FileUtils.mkdir_p(sibling)

        expect(Bolt::Project.find_boltdir(sibling)).to eq(project)
      end

      it 'finds the project from a child directory' do
        child = project_path + 'baz'
        FileUtils.mkdir_p(child)

        expect(Bolt::Project.find_boltdir(child)).to eq(project)
      end
    end

    describe "when using a control repo-style project" do
      it 'uses the current directory if it has a bolt.yaml' do
        FileUtils.touch(tmpdir + 'bolt.yaml')
        expect(Bolt::Project.find_boltdir(tmpdir)).to eq(Bolt::Project.new({}, tmpdir))
      end

      it 'ignores non-project children with bolt.yaml' do
        FileUtils.mkdir_p(tmpdir + 'bar')
        FileUtils.touch(tmpdir + 'bar' + 'bolt.yaml')

        expect(Bolt::Project.find_boltdir(tmpdir)).to eq(Bolt::Project.default_project)
      end

      it 'prefers a directory called Boltdir over the local directory' do
        FileUtils.touch(project_path.parent + 'bolt.yaml')
        expect(Bolt::Project.find_boltdir(project_path.parent)).to eq(project)
      end

      it 'prefers a directory called Boltdir over the parent directory' do
        sibling = project_path.parent + 'bar'
        FileUtils.mkdir_p(sibling)
        FileUtils.touch(project_path.parent + 'bolt.yaml')
        expect(Bolt::Project.find_boltdir(sibling)).to eq(project)
      end
    end

    describe 'when setting a type' do
      it 'sets type to embedded when a project is used' do
        expect(Bolt::Project.find_boltdir(project_path.parent).type).to eq('embedded')
      end

      it 'sets type to local when a bolt.yaml is used' do
        FileUtils.touch(tmpdir + 'bolt.yaml')
        expect(Bolt::Project.find_boltdir(tmpdir).type).to eq('local')
      end

      it 'sets type to user when the default is used' do
        expect(Bolt::Project.find_boltdir(tmpdir).type).to eq('user')
      end
    end

    it 'returns the default when no project is found' do
      expect(Bolt::Project.find_boltdir(tmpdir)).to eq(Bolt::Project.default_project)
    end
  end

  describe "::create_project" do
    let(:path)     { 'world_writable' }
    let(:pathname) { Pathname.new(path) }

    before(:each) do
      allow(Pathname).to receive(:new).and_call_original
      allow(Pathname).to receive(:new).with(path).and_return(pathname)
      allow(pathname).to receive(:expand_path).and_return(pathname)
      allow(pathname).to receive(:world_writable?).and_return(true)
      allow(File).to receive(:directory?).with(path).and_return(true)
    end

    it 'errors when loading from a world-writable directory', :bash do
      expect { Bolt::Project.create_project(path) }.to raise_error(/Project directory '#{pathname}' is world-writable/)
    end

    it 'loads from a world-writable directory when project is from environment variable' do
      expect { Bolt::Project.create_project(path, 'environment') }.not_to raise_error
    end

    it 'creates user-level project if it does not exist' do
      expect(FileUtils).to receive(:mkdir_p).with('myproject')
      Bolt::Project.create_project('myproject', 'user')
    end

    it 'warns and continues if project creation fails' do
      expect(FileUtils).to receive(:mkdir_p).with('myproject').and_raise(Errno::EACCES)
      # Ensure execution continues
      expect(Bolt::Project).to receive(:new).with(anything, 'myproject', 'user',
                                                  [{ warn: /Could not create default project / }])
      Bolt::Project.create_project('myproject', 'user')
    end
  end

  describe '#modulepath' do
    let(:project_config) { { 'modules' => [] } }

    around(:each) do |example|
      with_project do
        example.run
      end
    end

    it 'returns the new default modulepath if modules is set' do
      expect(project.modulepath).to match_array([(project_path + 'modules').to_s])
    end

    it 'returns the old default modulepath if modules is not set' do
      delete_config
      expect(project.modulepath).to match_array([
                                                  (project_path + 'modules').to_s,
                                                  (project_path + 'site-modules').to_s,
                                                  (project_path + 'site').to_s
                                                ])
    end
  end
end
