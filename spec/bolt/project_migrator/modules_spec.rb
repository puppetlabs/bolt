# frozen_string_literal: true

require 'bolt/project_migrator/modules'

describe Bolt::ProjectMigrator::Modules do
  def migrate
    migrator.migrate(project, modulepath)
  end

  def make_moduledirs
    FileUtils.mkdir_p(@tmpdir + 'modules' + 'foo')
    FileUtils.touch(@tmpdir + 'modules' + 'foo' + 'good')

    FileUtils.mkdir_p(@tmpdir + 'site-modules' + 'bar')
    FileUtils.touch(@tmpdir + 'site-modules' + 'bar' + 'good')

    FileUtils.mkdir_p(@tmpdir + 'site' + 'bar')
    FileUtils.mkdir_p(@tmpdir + 'site' + 'baz')
    FileUtils.touch(@tmpdir + 'site' + 'bar' + 'bad')
    FileUtils.touch(@tmpdir + 'site' + 'baz' + 'good')
  end

  let(:outputter) {
    double('outputter',
           print_message: nil,
           print_action_step: nil,
           print_action_error: nil)
  }
  let(:project_config) { {} }
  let(:project)        { Bolt::Project.new(project_config, @tmpdir) }
  let(:modulepath)     { project.modulepath }
  let(:migrator)       { described_class.new(outputter) }

  around(:each) do |example|
    Dir.mktmpdir(nil, Dir.pwd) do |tmpdir|
      @tmpdir = Pathname.new(tmpdir)
      example.run
    end
  end

  before(:each) do
    File.write(project.project_file, project_config)
  end

  context 'with modules configured' do
    let(:project_config) { { 'modules' => [] } }

    it 'does not migrate' do
      expect(migrate).to be(true)
      expect(File.exist?(project.managed_moduledir)).to be(false)
    end
  end

  context 'with a non-default modulepath' do
    let(:modulepath) { [(@tmpdir + 'modules').to_s] }

    it 'does not migrate' do
      migrate
      expect(File.exist?(project.managed_moduledir)).to be(false)
    end
  end

  context 'with a Puppetfile' do
    let(:puppetfile_content) { "mod 'puppetlabs-yaml', '0.1.0'" }

    before(:each) do
      allow(Bolt::Util).to receive(:prompt_yes_no).and_return(true)
      File.write(project.puppetfile, puppetfile_content)

      FileUtils.mkdir_p(@tmpdir + 'modules' + 'yaml')
      FileUtils.mkdir_p(@tmpdir + 'modules' + 'ruby_task_helper')
      make_moduledirs
    end

    it 'does not migrate if unable to parse the Puppetfile' do
      File.write(project.puppetfile, "mod 'puppetlabs-yaml' '0.1.0'")
      expect(migrate).to be(false)
      expect(File.exist?(project.managed_moduledir)).to be(false)
    end

    it 'does not migrate if unable to resolve dependencies' do
      content = "mod 'puppetlabs-yaml', '0.1.0'\nmod 'puppetlabs-ruby_task_helper', '0.3.0'"
      File.write(project.puppetfile, content)
      expect(migrate).to be(false)
      expect(File.exist?(project.managed_moduledir)).to be(false)
    end

    it 'writes a new Puppetfile with resolved dependencies' do
      expect(migrate).to be(true)
      expect(File.read(project.puppetfile).lines).to include(
        %r{puppetlabs/yaml}, %r{puppetlabs/ruby_task_helper}
      )
    end

    it 'writes a new Puppetfile with the new moduledir' do
      expect(migrate).to be(true)
      expect(File.read(project.puppetfile).lines).to include(
        /moduledir '.*\.modules'/
      )
    end

    it 'installs modules to the managed moduledir' do
      expect(migrate).to be(true)
      expect(Dir.exist?(project.managed_moduledir)).to be(true)
    end

    it 'removes managed modules from the modulepath' do
      expect(Dir.children(@tmpdir + 'modules')).to include('yaml', 'ruby_task_helper')
      expect(migrate).to be(true)
      expect(Dir.children(@tmpdir + 'modules')).not_to include('yaml', 'ruby_task_helper')
    end

    it 'consolidates non-managed modules' do
      expect(migrate).to be(true)
      expect(Dir.children(@tmpdir + 'modules')).to include('foo', 'bar', 'baz')
    end

    it 'does not overwrite modules from moduledirs earlier in the modulepath' do
      expect(migrate).to be(true)

      Dir.children(@tmpdir + 'modules').each do |mod|
        expect(Dir.children(@tmpdir + 'modules' + mod)).to match_array(%w[good])
      end
    end

    it 'removes unused moduledirs' do
      expect(migrate).to be(true)
      expect(Dir.exist?(@tmpdir + 'site-modules')).to be(false)
      expect(Dir.exist?(@tmpdir + 'site')).to be(false)
    end

    it 'configures modules with the selected modules' do
      expect(migrate).to be(true)
      data = Bolt::Util.read_yaml_hash(project.project_file, 'project')
      expect(data['modules']).to match_array([
                                               { 'name' => 'puppetlabs/yaml', 'version_requirement' => '0.1.0' }
                                             ])
    end

    it 'unconfigures the modulepath' do
      expect(migrate).to be(true)
      data = Bolt::Util.read_yaml_hash(project.project_file, 'project')
      expect(data['modulepath']).to be(nil)
    end

    context 'with a non-versioned module' do
      let(:puppetfile_content) { "mod 'puppetlabs-yaml'" }

      it 'does not set a version requirement' do
        expect(migrate).to be(true)
        data = Bolt::Util.read_yaml_hash(project.project_file, 'project')
        expect(data['modules']).to match_array([
                                                 { 'name' => 'puppetlabs/yaml' }
                                               ])
      end
    end

    context 'with a :latest version module' do
      let(:puppetfile_content) { "mod 'puppetlabs-yaml', :latest" }

      it 'does not set a version requirement' do
        expect(migrate).to be(true)
        data = Bolt::Util.read_yaml_hash(project.project_file, 'project')
        expect(data['modules']).to match_array([
                                                 { 'name' => 'puppetlabs/yaml' }
                                               ])
      end
    end

    context 'without any managed modules' do
      before(:each) do
        allow(Bolt::Util).to receive(:prompt_yes_no).and_return(false)
      end

      it 'deletes the Puppetfile' do
        expect(migrate).to be(true)
        expect(File.exist?(project.puppetfile)).to be(false)
      end

      it 'does not create the managed moduledir' do
        expect(migrate).to be(true)
        expect(Dir.exist?(project.managed_moduledir)).to be(false)
      end

      it 'consolidates the Puppetfile modules' do
        expect(migrate).to be(true)
        expect(Dir.children(@tmpdir + 'modules')).to include('yaml', 'ruby_task_helper')
      end

      it 'configures modules as an empty array' do
        expect(migrate).to be(true)
        data = Bolt::Util.read_yaml_hash(project.project_file, 'project')
        expect(data['modules']).to match_array([])
      end
    end
  end

  context 'without a Puppetfile' do
    before(:each) do
      make_moduledirs
    end

    it 'consolidates modules into the first moduledir' do
      expect(migrate).to be(true)
      expect(Dir.exist?(@tmpdir + 'modules')).to be(true)
      expect(Dir.children(@tmpdir + 'modules')).to match_array(%w[foo bar baz])
    end

    it 'does not overwrite modules from moduledirs earlier in the modulepath' do
      expect(migrate).to be(true)

      Dir.children(@tmpdir + 'modules').each do |mod|
        expect(Dir.children(@tmpdir + 'modules' + mod)).to match_array(%w[good])
      end
    end

    it 'removes unused moduledirs' do
      expect(migrate).to be(true)
      expect(Dir.exist?(@tmpdir + 'site-modules')).to be(false)
      expect(Dir.exist?(@tmpdir + 'site')).to be(false)
    end

    it 'does not create the managed moduledir' do
      expect(migrate).to be(true)
      expect(Dir.exist?(project.managed_moduledir)).to be(false)
    end

    it 'configures modules as an empty array' do
      expect(migrate).to be(true)
      data = Bolt::Util.read_yaml_hash(project.project_file, 'project')
      expect(data['modules']).to match_array([])
    end

    it 'unconfigures the modulepath' do
      expect(migrate).to be(true)
      data = Bolt::Util.read_yaml_hash(project.project_file, 'project')
      expect(data['modulepath']).to be(nil)
    end
  end
end
