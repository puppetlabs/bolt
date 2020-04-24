# frozen_string_literal: true

require 'spec_helper'
require 'bolt/project'

describe Bolt::Project do
  describe "configuration" do
    let(:pwd) { @tmpdir }
    let(:config) { { 'tasks' => ['facts'] } }

    before(:each) do
      allow(Bolt::Util).to receive(:read_optional_yaml_hash)
        .with(File.expand_path(@tmpdir + 'project.yaml'), 'project')
        .and_return(config)
    end

    around(:each) do |example|
      Dir.mktmpdir do |tmpdir|
        @tmpdir = Pathname.new(tmpdir)
        FileUtils.touch(@tmpdir + 'bolt.yaml')
        example.run
      end
    end

    it "loads config with defaults" do
      project = Bolt::Project.new(pwd)
      expect(project.tasks).to eq(config['tasks'])
      expect(project.plans).to eq(nil)
    end

    describe "validate" do
      let(:config) { { 'tasks' => 'foo' } }

      it "validates config" do
        expect { Bolt::Project.new(pwd) }.to raise_error(/'tasks' in project.yaml must be an array/)
      end
    end
  end

  describe "::find_boltdir" do
    let(:boltdir_path) { @tmpdir + 'foo' + 'Boltdir' }
    let(:project) { Bolt::Project.new(boltdir_path) }

    around(:each) do |example|
      Dir.mktmpdir do |tmpdir|
        @tmpdir = Pathname.new(tmpdir)
        FileUtils.mkdir_p(boltdir_path)
        example.run
      end
    end

    describe "when the project directory is named Boltdir" do
      it 'finds project from inside project' do
        pwd = boltdir_path
        expect(Bolt::Project.find_boltdir(pwd)).to eq(project)
      end

      it 'finds project from the parent directory' do
        pwd = boltdir_path.parent
        expect(Bolt::Project.find_boltdir(pwd)).to eq(project)
      end

      it 'does not find project from the grandparent directory' do
        pwd = boltdir_path.parent.parent
        expect(Bolt::Project.find_boltdir(pwd)).not_to eq(project)
      end

      it 'finds the project from a sibling directory' do
        pwd = boltdir_path.parent + 'bar'
        FileUtils.mkdir_p(pwd)

        expect(Bolt::Project.find_boltdir(pwd)).to eq(project)
      end

      it 'finds the project from a child directory' do
        pwd = boltdir_path + 'baz'
        FileUtils.mkdir_p(pwd)

        expect(Bolt::Project.find_boltdir(pwd)).to eq(project)
      end
    end

    describe "when using a control repo-style project" do
      it 'uses the current directory if it has a bolt.yaml' do
        pwd = @tmpdir
        FileUtils.touch(pwd + 'bolt.yaml')
        expect(Bolt::Project.find_boltdir(pwd)).to eq(Bolt::Project.new(pwd))
      end

      it 'ignores non-project children with bolt.yaml' do
        pwd = @tmpdir
        FileUtils.mkdir_p(pwd + 'bar')
        FileUtils.touch(pwd + 'bar' + 'bolt.yaml')

        expect(Bolt::Project.find_boltdir(pwd)).to eq(Bolt::Project.default_project)
      end

      it 'prefers a directory called project over the local directory' do
        pwd = boltdir_path.parent
        FileUtils.touch(pwd + 'bolt.yaml')

        expect(Bolt::Project.find_boltdir(pwd)).to eq(project)
      end

      it 'prefers a directory called project over the parent directory' do
        pwd = boltdir_path.parent + 'bar'
        FileUtils.mkdir_p(pwd)
        FileUtils.touch(boltdir_path.parent + 'bolt.yaml')

        expect(Bolt::Project.find_boltdir(pwd)).to eq(project)
      end
    end

    describe 'when setting a type' do
      it 'sets type to embedded when a project is used' do
        pwd = boltdir_path.parent
        expect(Bolt::Project.find_boltdir(pwd).type).to eq('embedded')
      end

      it 'sets type to local when a bolt.yaml is used' do
        pwd = @tmpdir
        FileUtils.touch(pwd + 'bolt.yaml')

        expect(Bolt::Project.find_boltdir(pwd).type).to eq('local')
      end

      it 'sets type to user when the default is used' do
        pwd = @tmpdir
        expect(Bolt::Project.find_boltdir(pwd).type).to eq('user')
      end
    end

    it 'returns the default when no project is found' do
      pwd = @tmpdir
      expect(Bolt::Project.find_boltdir(pwd)).to eq(Bolt::Project.default_project)
    end
  end
end
