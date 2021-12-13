# frozen_string_literal: true

require 'bolt_spec/conn'
require 'bolt_spec/integration'
require 'bolt_spec/project'

describe 'policy' do
  include BoltSpec::Conn
  include BoltSpec::Integration
  include BoltSpec::Project

  let(:config)    { {} }
  let(:inventory) { {} }

  around(:each) do |example|
    with_project('policy', config: config, inventory: inventory) do |project|
      @project = project
      example.run
    end
  end

  describe 'apply', ssh: true do
    include BoltSpec::Conn

    let(:config)    { { 'policies' => %w[policy::foo policy::bar policy::define] } }
    let(:inventory) { docker_inventory }
    let(:opts)      { %w[-t puppet_7_node] }

    before(:each) do
      FileUtils.mkdir_p(@project.manifests)

      File.write(@project.manifests + 'foo.pp', <<~FOO)
        class policy::foo {
          notice('policy::foo')
        }
      FOO

      File.write(@project.manifests + 'bar.pp', <<~BAR)
        class policy::bar {
          notice('policy::bar')
        }
      BAR

      File.write(@project.manifests + 'define.pp', <<~DEFINE)
        define policy::define {
          include policy::foo, policy::bar
        }
      DEFINE
    end

    it 'applies a single policy' do
      result = run_cli(%w[policy apply policy::foo] + opts, project: @project, outputter: Bolt::Outputter::Human)

      expect(result).to match(/apply catalog with 0 failures/)
    end

    it 'applies multiple policies' do
      result = run_cli(%w[policy apply policy::foo] + opts, project: @project, outputter: Bolt::Outputter::Human)

      expect(result).to match(/apply catalog with 0 failures/)
    end

    context 'with glob patterns' do
      let(:config) { { 'policies' => %w[policy::*] } }

      it 'applies policies matching the glob pattern' do
        result = run_cli(%w[policy apply policy::foo] + opts, project: @project, outputter: Bolt::Outputter::Human)

        expect(result).to match(/apply catalog with 0 failures/)
      end
    end

    it 'errors with unavailable policies' do
      expect {
        run_cli(%w[policy apply policy::baz] + opts, project: @project)
      }.to raise_error(
        Bolt::Error,
        /The following policies are not available to the project: 'policy::baz'/
      )
    end

    it 'errors with unloadable policies' do
      expect {
        run_cli(%w[policy apply policy::define] + opts, project: @project)
      }.to raise_error(
        Bolt::Error,
        /The following policies cannot be loaded: 'policy::define'/
      )
    end
  end

  describe 'new' do
    let(:config) { { 'policies' => %w[example] } }

    it 'creates a new policy in the project' do
      result = run_cli_json(%w[policy new policy::foo::bar], project: @project)

      expect(result['name']).to eq('policy::foo::bar')
      expect(result['path']).to eq((@project.manifests + 'foo' + 'bar.pp').to_s)
      expect(File.exist?(result['path'])).to be
      expect(File.read(result['path'])).to match(/class policy::foo::bar/)
    end

    it 'creates a new init class in the project' do
      result = run_cli_json(%w[policy new policy], project: @project)

      expect(result['name']).to eq('policy')
      expect(result['path']).to eq((@project.manifests + 'init.pp').to_s)
      expect(File.exist?(result['path'])).to be
      expect(File.read(result['path'])).to match(/class policy/)
    end

    it 'adds the new policy to the project config' do
      run_cli_json(%w[policy new policy], project: @project)

      project_config = Bolt::Util.read_yaml_hash(@project.project_file, 'project config')
      expect(project_config['policies']).to match_array(%w[example policy])
    end

    context 'without policies configured' do
      let(:config) { {} }

      it 'adds a policies key with the new policy' do
        run_cli_json(%w[policy new policy], project: @project)

        project_config = Bolt::Util.read_yaml_hash(@project.project_file, 'project config')
        expect(project_config['policies']).to match_array(%w[policy])
      end
    end

    it 'errors with an invalid name' do
      expect { run_cli_json(%w[policy new 123::abc], project: @project) }
        .to raise_error(
          Bolt::ValidationError,
          /Invalid policy name '123::abc'/
        )
    end

    it 'errors when name is not prefixed with project name' do
      expect { run_cli_json(%w[policy new foo::bar], project: @project) }
        .to raise_error(
          Bolt::ValidationError,
          /Policy name 'foo::bar' must begin with project name 'policy'/
        )
    end

    it 'errors if the destination file already exists' do
      FileUtils.mkdir_p(@project.manifests)
      FileUtils.touch(@project.manifests + 'init.pp')

      expect { run_cli_json(%w[policy new policy], project: @project) }
        .to raise_error(
          Bolt::Error,
          /A policy with the name 'policy' already exists at '#{@project.manifests + 'init.pp'}'/
        )
    end

    it 'errors if the directory structure cannot be created' do
      FileUtils.mkdir_p(@project.manifests)
      FileUtils.touch(@project.manifests + 'foo')

      expect { run_cli_json(%w[policy new policy::foo::bar], project: @project) }
        .to raise_error(
          Bolt::Error,
          /unable to create manifests directory '#{@project.manifests + 'foo'}'/
        )
    end
  end

  describe 'show' do
    context 'with policies configured' do
      let(:config) { { 'policies' => %w[policy::foo policy::bar] } }

      it 'lists available policies' do
        result = run_cli_json(%w[policy show], project: @project)

        expect(result['policies']).to match_array(%w[policy::foo policy::bar])
        expect(result['modulepath']).to be
      end
    end

    context 'without policies configured' do
      let(:config) { {} }

      it 'errors with a helpful message' do
        expect { run_cli_json(%w[policy show], project: @project) }
          .to raise_error(
            Bolt::Error,
            /Project configuration file .* does not specify any policies/
          )
      end
    end
  end
end
