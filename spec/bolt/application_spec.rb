# frozen_string_literal: true

require 'bolt/application'

require 'bolt_spec/files'

describe Bolt::Application do
  include BoltSpec::Files

  let(:analytics)  { double('analytics').as_null_object }
  let(:config)     { double('config').as_null_object }
  let(:executor)   { double('executor').as_null_object }
  let(:inventory)  { double('inventory', get_targets: targets).as_null_object }
  let(:pal)        { double('pal').as_null_object }
  let(:pdb_client) { double('pdb_client').as_null_object }
  let(:plugins)    { double('plugins', puppetdb_client: pdb_client).as_null_object }

  let(:application) do
    described_class.new(
      analytics: analytics,
      config:    config,
      executor:  executor,
      inventory: inventory,
      pal:       pal,
      plugins:   plugins
    )
  end

  let(:target)  { double('target').as_null_object }
  let(:targets) { ['localhost'] }

  before(:each) do
    allow(application).to receive(:with_benchmark) { |&block| block.call }
  end

  describe '#apply' do
    let(:ast)      { double('ast', body: body) }
    let(:body)     { double('body').as_null_object }
    let(:code)     { "notice('hello')" }
    let(:manifest) { '/path/to/manifest.pp' }

    before(:each) do
      allow(File).to receive(:read).with(manifest).and_return(code)
    end

    it 'errors if the manifest file does not exist' do
      stub_nonexistent_file(manifest)

      expect { application.apply(manifest, targets) }.to raise_error(
        Bolt::FileError,
        /The manifest '#{manifest}' does not exist/
      )
    end

    it 'errors if the manifest file is unreadable' do
      stub_unreadable_file(manifest)

      expect { application.apply(manifest, targets) }.to raise_error(
        Bolt::FileError,
        /The manifest '#{manifest}' is unreadable/
      )
    end

    it 'errors if the manifest file is not a file' do
      stub_directory(manifest)

      expect { application.apply(manifest, targets) }.to raise_error(
        Bolt::FileError,
        /The manifest '#{manifest}' is not a file/
      )
    end

    it 'warns if the manifest only contains definitions' do
      allow(body).to receive(:is_a?).with(Puppet::Pops::Model::HostClassDefinition).and_return(true)
      allow(pal).to receive(:parse_manifest).and_return(ast)

      application.apply(nil, targets, code: "notice('test')")

      expect(@log_output.readlines).to include(
        /WARN .* Manifest only contains definitions/
      )
    end
  end

  describe '#file_download' do
    let(:destination) { File.expand_path('/path/to/destination') }
    let(:source)      { File.expand_path('/path/to/source') }

    it 'downloads a file' do
      expect(executor).to receive(:download_file).with(targets, source, destination)

      application.file_download(source, destination, targets)
    end
  end

  describe '#file_upload' do
    let(:destination) { File.expand_path('/path/to/destination') }
    let(:source)      { File.expand_path('/path/to/source') }

    it 'uploads a file' do
      stub_file(source)
      expect(executor).to receive(:download_file).with(targets, source, destination)

      application.file_download(source, destination, targets)
    end

    it 'uploads a directory' do
      stub_directory(source)
      expect(executor).to receive(:download_file).with(targets, source, destination)

      application.file_download(source, destination, targets)
    end

    it 'errors if the source does not exist' do
      stub_nonexistent_file(source)

      expect { application.file_upload(source, destination, targets) }.to raise_error(
        Bolt::FileError,
        /The source file '#{source}' does not exist/
      )
    end

    it 'errors if the source is unreadable' do
      stub_unreadable_file(source)

      expect { application.file_upload(source, destination, targets) }.to raise_error(
        Bolt::FileError,
        /The source file '#{source}' is unreadable/
      )
    end

    it 'errors if a file in a subdirectory is unreadable' do
      child = File.join(source, 'child')
      stub_directory(source)
      stub_unreadable_file(child)
      allow(Dir).to receive(:foreach).with(source).and_yield('child')

      expect { application.file_upload(source, destination, targets) }.to raise_error(
        Bolt::FileError,
        /The source file '#{child}' is unreadable/
      )
    end
  end

  describe '#inventory_show' do
    it 'shows specified targets' do
      expect(inventory).to receive(:get_targets).with(targets).and_return([target])
      application.inventory_show(targets)
    end

    it 'defaults to showing all targets' do
      expect(inventory).to receive(:get_targets).with(['all']).and_return([target])
      application.inventory_show(nil)
    end
  end

  describe '#plan_run' do
    let(:plan)        { 'plan' }
    let(:plan_info)   { { 'parameters' => plan_params } }
    let(:plan_params) { {} }

    before(:each) do
      allow(pal).to receive(:get_plan_info).and_return(plan_info)
    end

    it 'runs a given plan' do
      expect(pal).to receive(:run_plan) do |plan,|
        expect(plan).to eq(plan)
      end

      application.plan_run(plan, targets)
    end

    context 'with TargetSpec $nodes parameter' do
      let(:plan_params) do
        {
          'nodes' => {
            'type' => 'TargetSpec'
          }
        }
      end

      it 'uses targets for the $nodes parameter' do
        expect(pal).to receive(:run_plan) do |_plan, params,|
          expect(params).to include('nodes' => targets.join(','))
        end

        application.plan_run(plan, targets)
      end

      it 'does not pass empty targets to the $nodes parameter' do
        expect(pal).to receive(:run_plan) do |_plan, params,|
          expect(params).to eq({})
        end

        application.plan_run(plan, [])
      end
    end

    context 'with TargetSpec $targets parameter' do
      let(:plan_params) do
        {
          'targets' => {
            'type' => 'TargetSpec'
          }
        }
      end

      it 'uses targets for the $targets parameter' do
        expect(pal).to receive(:run_plan) do |_plan, params,|
          expect(params).to include('targets' => targets.join(','))
        end

        application.plan_run(plan, targets)
      end

      it 'does not pass empty targets to the $nodes parameter' do
        expect(pal).to receive(:run_plan) do |_plan, params,|
          expect(params).to eq({})
        end

        application.plan_run(plan, [])
      end
    end

    context 'with TargetSpec $nodes and TargetSpec $targets parameters' do
      let(:plan_params) do
        {
          'nodes' => {
            'type' => 'TargetSpec'
          },
          'targets' => {
            'type' => 'TargetSpec'
          }
        }
      end

      it 'does not use targets for either parameter' do
        expect(pal).to receive(:run_plan) do |_plan, params,|
          expect(params).not_to include('nodes', 'targets')
        end

        application.plan_run(plan, targets)

        expect(@log_output.readlines).to include(
          /WARN .* Plan parameters include both 'nodes' and 'targets'/
        )
      end
    end

    it 'errors if targets are specified twice' do
      params = { 'targets' => targets }

      expect { application.plan_run(plan, targets, params: params) }.to raise_error(
        Bolt::CLIError,
        /A plan's 'targets' parameter can be specified using the --targets option/
      )
    end
  end

  describe '#script_run' do
    let(:script) { '/path/to/script.sh' }

    it 'runs a script' do
      stub_file(script)
      expect(executor).to receive(:run_script).with(targets, script, anything, anything)

      application.script_run(script, targets)
    end

    it 'errors if the script does not exist' do
      stub_nonexistent_file(script)

      expect { application.script_run(script, targets) }.to raise_error(
        Bolt::FileError,
        /The script '#{script}' does not exist/
      )
    end

    it 'errors if the script is unreadable' do
      stub_unreadable_file(script)

      expect { application.script_run(script, targets) }.to raise_error(
        Bolt::FileError,
        /The script '#{script}' is unreadable/
      )
    end

    it 'errors if the script is not a file' do
      stub_directory(script)

      expect { application.script_run(script, targets) }.to raise_error(
        Bolt::FileError,
        /The script '#{script}' is not a file/
      )
    end
  end

  describe '#task_run' do
    let(:task) { 'task' }

    it 'runs a given task' do
      expect(pal).to receive(:run_task) do |task,|
        expect(task).to eq(task)
      end

      application.task_run(task, targets)
    end
  end
end
