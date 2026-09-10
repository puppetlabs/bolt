# frozen_string_literal: true

require 'spec_helper'
require 'bolt/inventory'
require 'bolt/task'

describe Bolt::Task do
  describe "#select_implementation" do
    let(:inventory) { Bolt::Inventory.empty }
    let(:target) { inventory.get_target('example') }
    let(:files) {
      [
        { 'name' => 'foo.sh',  'path' => '/foo.sh' },
        { 'name' => 'foo.ps1', 'path' => 'C:/foo.ps1' },
        { 'name' => 'foo.rb',  'path' => '/foo.rb' }
      ]
    }
    let(:implementations) { [] }
    let(:metadata) { { 'implementations' => implementations } }
    let(:task) { Bolt::Task.new('foo', metadata, files) }

    before :each do
      allow(target).to receive(:feature_set).and_return(Set.new(['powershell']))
    end

    context 'with input_method in metadata' do
      let(:implementations) { [{ 'name' => 'foo.sh', 'requirements' => [] }] }
      let(:metadata) { { 'input_method' => 'stdin', 'implementations' => implementations } }
      let(:expected) { files.first.merge('input_method' => 'stdin', 'files' => []) }

      it { expect(task.select_implementation(target)).to eq(expected) }

      context 'with input_method in implementation' do
        let(:implementations) { [{ 'name' => 'foo.sh', 'requirements' => [], 'input_method' => 'environment' }] }
        let(:expected) { files.first.merge('input_method' => 'environment', 'files' => []) }

        it { expect(task.select_implementation(target)).to eq(expected) }
      end
    end

    context 'no metadata present' do
      let(:metadata) { {} }

      it { expect(task.select_implementation(target)).to eq(files.first.merge('files' => [])) }
    end

    context 'implementations have no requirements' do
      let(:implementations) {
        [{ 'name' => 'foo.sh', 'requirements' => [] },
         { 'name' => 'foo.ps1', 'requirements' => [] }]
      }

      it { expect(task.select_implementation(target)).to eq(files.first.merge('files' => [])) }
    end

    context 'second implementation matches available feature' do
      let(:implementations) {
        [{ 'name' => 'foo.sh', 'requirements' => ['shell'] },
         { 'name' => 'foo.ps1', 'requirements' => ['powershell'] }]
      }

      it { expect(task.select_implementation(target)).to eq(files[1].merge('files' => [])) }
    end

    context 'first implementation requires extra features' do
      let(:implementations) {
        [{ 'name' => 'foo.rb', 'requirements' => %w[powershell puppet-agent] },
         { 'name' => 'foo.ps1', 'requirements' => ['powershell'] }]
      }

      it { expect(task.select_implementation(target)).to eq(files[1].merge('files' => [])) }

      it 'uses additional features passed as arguments' do
        expect(task.select_implementation(target, ['puppet-agent'])).to eq(files[2].merge('files' => []))
      end
    end

    context 'no suitable implementation' do
      let(:implementations) {
        [{ 'name' => 'foo.rb', 'requirements' => %w[powershell puppet-agent] },
         { 'name' => 'foo.ps1', 'requirements' => %w[powershell foobar] }]
      }

      it {
        expect { task.select_implementation(target) }.to raise_error('No suitable implementation of foo for example')
      }
    end

    context 'with additional files in implementation' do
      let(:implementations) do
        [{ 'name' => 'foo.sh', 'requirements' => [], 'files' => ['foo.rb'] }]
      end

      it 'includes named files in the result' do
        result = task.select_implementation(target)
        expect(result['files']).to include(a_hash_including('name' => 'foo.rb'))
      end
    end

    context 'with directory files in metadata' do
      let(:files) do
        [
          { 'name' => 'foo.sh', 'path' => '/foo.sh' },
          { 'name' => 'lib/helper.rb', 'path' => '/lib/helper.rb' }
        ]
      end
      let(:implementations) { [{ 'name' => 'foo.sh', 'requirements' => [] }] }
      let(:metadata) { { 'implementations' => implementations, 'files' => ['lib/'] } }

      it 'includes directory-matched files' do
        result = task.select_implementation(target)
        expect(result['files'].map { |f| f['name'] }).to include('lib/helper.rb')
      end
    end
  end

  describe '#description' do
    it 'returns the description from metadata' do
      task = Bolt::Task.new('foo', { 'description' => 'Does stuff' }, [])
      expect(task.description).to eq('Does stuff')
    end
  end

  describe '#parameters' do
    it 'returns parameters from metadata' do
      task = Bolt::Task.new('foo', { 'parameters' => { 'name' => { 'type' => 'String' } } }, [])
      expect(task.parameters).to eq('name' => { 'type' => 'String' })
    end
  end

  describe '#parameter_defaults' do
    it 'returns defaults for parameters that have them' do
      meta = { 'parameters' => { 'count' => { 'type' => 'Integer', 'default' => 5 },
                                 'name' => { 'type' => 'String' } } }
      task = Bolt::Task.new('foo', meta, [])
      expect(task.parameter_defaults).to eq('count' => 5)
    end

    it 'returns an empty hash when there are no parameters' do
      task = Bolt::Task.new('foo', {}, [])
      expect(task.parameter_defaults).to eq({})
    end
  end

  describe '#supports_noop' do
    it 'returns the supports_noop value from metadata' do
      task = Bolt::Task.new('foo', { 'supports_noop' => true }, [])
      expect(task.supports_noop).to be true
    end
  end

  describe '#module_name' do
    it 'returns the module part of the task name' do
      task = Bolt::Task.new('mymodule::mytask', {}, [])
      expect(task.module_name).to eq('mymodule')
    end

    it 'returns the task name itself for uninamespaced tasks' do
      task = Bolt::Task.new('mytask', {}, [])
      expect(task.module_name).to eq('mytask')
    end
  end

  describe '#tasks_dir' do
    it 'returns the tasks directory path' do
      task = Bolt::Task.new('mymodule::mytask', {}, [])
      expect(task.tasks_dir).to eq('mymodule/tasks')
    end
  end

  describe '#remote_instance' do
    it 'creates a remote version of the task' do
      task = Bolt::Task.new('foo', { 'description' => 'hi' }, [])
      remote = task.remote_instance
      expect(remote.remote).to be true
      expect(remote.name).to eq('foo')
    end
  end

  describe '#eql? / ==' do
    let(:task_a) { Bolt::Task.new('foo', {}, []) }
    let(:task_b) { Bolt::Task.new('foo', {}, []) }

    it 'returns true for identical tasks' do
      expect(task_a).to eq(task_b)
    end

    it 'returns false for tasks with different names' do
      task_c = Bolt::Task.new('bar', {}, [])
      expect(task_a).not_to eq(task_c)
    end
  end

  describe '#to_h' do
    it 'returns a hash with name, files, and metadata' do
      task = Bolt::Task.new('foo', { 'description' => 'hi' }, [{ 'name' => 'foo.sh', 'path' => '/foo.sh' }])
      h = task.to_h
      expect(h[:name]).to eq('foo')
      expect(h[:files]).to be_an(Array)
      expect(h[:metadata]).to include('description' => 'hi')
    end
  end

  describe '#validate_metadata' do
    it 'warns on unknown metadata keys' do
      expect(Bolt::Logger).to receive(:warn).with('unknown_task_metadata_keys', /unknown keys/)
      Bolt::Task.new('foo', { 'unknown_key' => 'value' }, [])
    end
  end

  describe 'Bolt::NoImplementationError' do
    let(:inventory) { Bolt::Inventory.empty }
    let(:target) { inventory.get_target('myhost') }
    let(:task) { Bolt::Task.new('mytask', {}, []) }

    it 'creates an error with task and target info' do
      err = Bolt::NoImplementationError.new(target, task)
      expect(err.kind).to eq('bolt/no-implementation')
      expect(err.message).to match(/mytask/)
      expect(err.message).to match(/myhost/)
    end
  end
end
