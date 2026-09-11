# frozen_string_literal: true

require 'spec_helper'
require 'bolt/pal/yaml_plan'
require 'bolt/util'
require 'bolt_spec/files'

describe Bolt::Util do
  include BoltSpec::Files

  context "when creating a typed name from a modulepath" do
    it "removes init from the typed name" do
      expect(Bolt::Util.module_name('mymod/plans/init.pp')).to eq('mymod')
      expect(Bolt::Util.module_name('mymod/tasks/init.html.erb')).to eq('mymod')
    end

    it "supports extended paths" do
      expect(Bolt::Util.module_name('mymod/plans/subdir/plan.pp')).to eq('mymod::subdir::plan')
    end

    it "splits on the first plans or tasks directory" do
      expect(Bolt::Util.module_name('mymod/plans/plans/myplan.pp')).to eq('mymod::plans::myplan')
      expect(Bolt::Util.module_name('mymod/tasks/plans/mytask.rb')).to eq('mymod::plans::mytask')
    end

    context "#to_code" do
      it "turns DoubleQuotedString types into code strings" do
        string = Bolt::PAL::YamlPlan::DoubleQuotedString.new('doublebubble')
        expect(Bolt::Util.to_code(string)).to eq("\"doublebubble\"")
      end

      context "turns BareString types into code strings" do
        it 'with a preceding variable' do
          string = Bolt::PAL::YamlPlan::BareString.new('$variable')
          expect(Bolt::Util.to_code(string)).to eq('$variable')
        end

        it 'with no variable' do
          string = Bolt::PAL::YamlPlan::BareString.new('nonvariable')
          expect(Bolt::Util.to_code(string)).to eq("'nonvariable'")
        end
      end

      it "turns CodeLiteral types into code strings" do
        string = Bolt::PAL::YamlPlan::CodeLiteral.new('[$codelit].join()')
        expect(Bolt::Util.to_code(string)).to eq('[$codelit].join()')
      end

      it "turns EvaluableString types into code strings" do
        string = Bolt::PAL::YamlPlan::EvaluableString.new('ev@l$tr1ng')
        expect(Bolt::Util.to_code(string)).to eq('ev@l$tr1ng')
      end

      it "turns Hashes into code strings" do
        hash = { 'hash' => Bolt::PAL::YamlPlan::BareString.new('$brown') }
        expect(Bolt::Util.to_code(hash)).to eq("{'hash' => $brown}")
      end

      it "turns Arrays into code string" do
        array = ['a', 'r', 'r', Bolt::PAL::YamlPlan::BareString.new('$a'), 'y']
        expect(Bolt::Util.to_code(array)).to eq("['a', 'r', 'r', $a, 'y']")
      end
    end
  end

  context "when parsing a yaml file with read_yaml_hash" do
    it "raises an error with line number if the YAML has a syntax error" do
      contents = <<-YAML
      ---
      version: 2
      config:
        transport: winrm
          ssl-verify: false
          ssl: true
      YAML

      with_tempfile_containing('config_file_test', contents) do |file|
        expect {
          Bolt::Util.read_yaml_hash(file, 'inventory')
        }.to raise_error(Bolt::FileError, /line 2, column 14/)
      end
    end

    it "does not error with line number if the YAML error does not include a line number" do
      contents = <<~YAML
        ---
        color: :true
      YAML

      with_tempfile_containing('config_file_test', contents) do |file|
        expect { Bolt::Util.read_yaml_hash(file, 'inventory') }.to raise_error do |error|
          expect(error.class).to be(Bolt::FileError)
          expect(error.message).not_to match(/line/)
        end
      end
    end

    it "returns an empty hash when the yaml file is empty" do
      with_tempfile_containing('empty', '') do |file|
        expect(Bolt::Util.read_yaml_hash(file, 'config')).to eq({})
      end
    end

    it "errors when file does not exist and is required" do
      expect {
        Bolt::Util.read_yaml_hash('does-not-exist', 'config')
      }.to raise_error(Bolt::FileError)
    end

    it "errors when a non-hash object is read from a yaml file" do
      contents = <<-YAML
      ---
      foo
      YAML
      with_tempfile_containing('config_file_test', contents) do |file|
        expect {
          Bolt::Util.read_yaml_hash(file, 'inventory')
        }.to raise_error(Bolt::FileError, /should be a Hash or empty, not String/)
      end
    end

    it "communicates that aliases are not supported" do
      contents = <<~YAML
      ---
      foo: &flag value
      bar: *flag
      YAML
      with_tempfile_containing('config_file_test', contents) do |file|
        expect {
          Bolt::Util.read_yaml_hash(file, 'inventory')
        }.to raise_error(Bolt::FileError, /does not support.*aliases/)
      end
    end
  end

  context "when parsing a yaml file with read_optional_yaml_hash" do
    it "returns an empty hash when the yaml file does not exist" do
      expect(Bolt::Util.read_optional_yaml_hash('does-not-exist', 'config')).to eq({})
    end
  end

  describe "#read_json_file" do
    it "reads a json file" do
      contents = "{\"my\": \"cool data\"}"

      with_tempfile_containing('json_test', contents) do |file|
        expect(Bolt::Util.read_json_file(file, 'inventory'))
          .to eq({ "my" => "cool data" })
      end
    end

    it "raises an error if JSON is invalid" do
      contents = "{\"invalid\": \"json\""

      with_tempfile_containing('json_test', contents) do |file|
        expect {
          Bolt::Util.read_json_file(file, 'json')
        }.to raise_error(Bolt::FileError, /Unable to parse json file at/)
      end
    end

    it "errors when file does not exist and is required" do
      expect {
        Bolt::Util.read_json_file('does-not-exist', 'json')
      }.to raise_error(Bolt::FileError, /Could not read json file at/)
    end
  end

  describe "#read_optional_json_file" do
    it "returns an empty hash when the json file does not exist" do
      expect(Bolt::Util.read_optional_json_file('does-not-exist', 'config')).to eq({})
    end

    it "returns an empty hash when the json file is empty" do
      Tempfile.create do |file|
        expect(Bolt::Util.read_optional_json_file(file.path, 'config')).to eq({})
      end
    end
  end

  describe '#deep_clone' do
    it 'works with frozen hashes' do
      hash = { key: 'value', boolean: true }
      hash.freeze
      expect(Bolt::Util.deep_clone(hash)).to eq(hash)
    end
  end

  describe '#first_runs_free' do
    it 'returns path to first run file under user-level default config dir' do
      expect(Bolt::Util.first_runs_free).to eq(Bolt::Config.user_path + '.first_runs_free')
    end

    it 'falls back to system_path if user_path fails to be created' do
      expect(FileUtils).to receive(:mkdir_p)
        .with(Bolt::Config.user_path).and_raise(Errno::ENOENT, "No such file or directory")
      expect(FileUtils).to receive(:mkdir_p)
        .with(Bolt::Config.system_path).and_return([Bolt::Config.system_path])
      expect(Bolt::Util.first_runs_free).to eq(Bolt::Config.system_path + '.first_runs_free')
    end

    it 'returns nil if both system_path and user_path fail to be created' do
      expect(FileUtils).to receive(:mkdir_p)
        .with(Bolt::Config.user_path).and_raise(Errno::ENOENT, "No such file or directory")
      expect(FileUtils).to receive(:mkdir_p)
        .with(Bolt::Config.system_path).and_raise(Errno::ENOENT, "No such file or directory")
      expect(Bolt::Util.first_runs_free).to eq(nil)
    end
  end

  describe '#prompt_yes_no' do
    let(:outputter) { double('outputter', print_prompt: nil, print_prompt_error: nil) }

    before(:each) do
      allow($stdin).to receive(:tty?).and_return(true)
    end

    %w[y yes].each do |response|
      it "returns true for #{response}" do
        allow($stdin).to receive(:gets).and_return(response)
        expect(Bolt::Util.prompt_yes_no('', outputter)).to be(true)
      end
    end

    %w[n no].each do |response|
      it "returns false for #{response}" do
        allow($stdin).to receive(:gets).and_return(response)
        expect(Bolt::Util.prompt_yes_no('', outputter)).to be(false)
      end
    end

    it 'reprompts on invalid input then returns true on valid input' do
      allow($stdin).to receive(:gets).and_return('maybe', 'yes')
      expect(outputter).to receive(:print_prompt_error).once
      expect(Bolt::Util.prompt_yes_no('proceed?', outputter)).to be(true)
    end
  end

  describe '#search_module' do
    it 'returns path under files/ if present' do
      Dir.mktmpdir do |mod_path|
        FileUtils.mkdir_p(File.join(mod_path, 'files'))
        File.write(File.join(mod_path, 'files', 'myfile.sh'), '')
        result = Bolt::Util.search_module(mod_path, 'myfile.sh')
        expect(result).to eq(File.join(mod_path, 'files', 'myfile.sh'))
      end
    end

    it 'falls back to module root if not under files/' do
      Dir.mktmpdir do |mod_path|
        File.write(File.join(mod_path, 'myfile.sh'), '')
        result = Bolt::Util.search_module(mod_path, 'myfile.sh')
        expect(result).to eq(File.join(mod_path, 'myfile.sh'))
      end
    end

    it 'returns nil when file is not found' do
      Dir.mktmpdir do |mod_path|
        expect(Bolt::Util.search_module(mod_path, 'nonexistent.sh')).to be_nil
      end
    end
  end

  describe '#split_path' do
    it 'splits a path into module and file components' do
      result = Bolt::Util.split_path('mymod/myfile.sh')
      expect(result).to eq(%w[mymod myfile.sh])
    end
  end

  describe '#module_name' do
    it 'raises an error when path does not contain plans or tasks' do
      expect {
        Bolt::Util.module_name('mymod/lib/something.rb')
      }.to raise_error(Bolt::Error, /plans.*tasks/)
    end
  end

  describe '#deep_merge!' do
    it 'merges hashes in place' do
      h1 = { 'a' => 1, 'b' => { 'x' => 1 } }
      h2 = { 'b' => { 'y' => 2 }, 'c' => 3 }
      result = Bolt::Util.deep_merge!(h1, h2)
      expect(result).to eq('a' => 1, 'b' => { 'x' => 1, 'y' => 2 }, 'c' => 3)
      expect(h1).to equal(result)
    end

    it 'overwrites non-hash values' do
      h1 = { 'a' => 'old' }
      h2 = { 'a' => 'new' }
      Bolt::Util.deep_merge!(h1, h2)
      expect(h1['a']).to eq('new')
    end
  end

  describe '#postwalk_vals' do
    it 'applies block to all values bottom-up' do
      data = { 'a' => [1, 2] }
      result = Bolt::Util.postwalk_vals(data) do |val|
        val.is_a?(Integer) ? val * 2 : val
      end
      expect(result).to eq('a' => [2, 4])
    end

    it 'skips the top value when skip_top is true' do
      called_with = []
      Bolt::Util.postwalk_vals([1, 2], true) { |v|
        called_with << v
        v
      }
      expect(called_with).not_to include([1, 2])
    end
  end

  describe '#deep_clone' do
    it 'clones nested arrays' do
      arr = [[1, 2], [3, 4]]
      cloned = Bolt::Util.deep_clone(arr)
      expect(cloned).to eq(arr)
      expect(cloned).not_to equal(arr)
      expect(cloned[0]).not_to equal(arr[0])
    end

    it 'handles objects with instance variables' do
      obj = Object.new
      obj.instance_variable_set(:@data, 'hello')
      cloned = Bolt::Util.deep_clone(obj)
      expect(cloned.instance_variable_get(:@data)).to eq('hello')
    end

    it 'handles true/false (unclonable)' do
      expect(Bolt::Util.deep_clone(true)).to be true
      expect(Bolt::Util.deep_clone(false)).to be false
    end

    it 'returns the same object when already cloned (circular ref protection)' do
      arr = [1, 2]
      cloned = {}
      cloned[arr.object_id] = arr # rubocop:disable Lint/HashCompareByIdentity
      result = Bolt::Util.deep_clone(arr, cloned)
      expect(result).to equal(arr)
    end

    it 'clones structs with pair iteration' do
      s = Struct.new(:x, :y).new('hello', 'world')
      cloned = Bolt::Util.deep_clone(s)
      expect(cloned.x).to eq('hello')
      expect(cloned.y).to eq('world')
      expect(cloned).not_to equal(s)
    end
  end

  describe '#exec_podman' do
    it 'calls Open3.capture3 with podman and the given command' do
      allow(Open3).to receive(:capture3).and_return(['stdout', 'stderr', double(exitstatus: 0)])
      stdout, _stderr, _status = Bolt::Util.exec_podman(['ps'])
      expect(stdout).to eq('stdout')
    end
  end

  describe '#class_name_to_file_name' do
    it 'converts a class name to a file path' do
      expect(Bolt::Util.class_name_to_file_name('Bolt::ApplyResult')).to eq('bolt/apply_result')
    end

    it 'handles CLI abbreviation correctly' do
      expect(Bolt::Util.class_name_to_file_name('Bolt::CLI')).to eq('bolt/cli')
    end
  end

  describe '#format_env_vars_for_cli' do
    it 'formats env vars as repeated --env flags' do
      result = Bolt::Util.format_env_vars_for_cli('FOO' => 'bar', 'BAZ' => 'qux')
      expect(result).to include('--env', 'FOO=bar', '--env', 'BAZ=qux')
    end

    it 'returns an empty array for empty input' do
      expect(Bolt::Util.format_env_vars_for_cli({})).to eq([])
    end
  end

  describe '#unix_basename' do
    it 'returns the last component of a unix path' do
      expect(Bolt::Util.unix_basename('/foo/bar/baz.rb')).to eq('baz.rb')
    end

    it 'raises an error for non-string input' do
      expect { Bolt::Util.unix_basename(42) }
        .to raise_error(Bolt::ValidationError, /must be a String/)
    end
  end

  describe '#windows_basename' do
    it 'returns the last component of a windows path' do
      expect(Bolt::Util.windows_basename('C:\\foo\\bar\\baz.rb')).to eq('baz.rb')
    end

    it 'returns the last component of a forward-slash path' do
      expect(Bolt::Util.windows_basename('C:/foo/bar/baz.rb')).to eq('baz.rb')
    end

    it 'raises an error for non-string input' do
      expect { Bolt::Util.windows_basename(nil) }
        .to raise_error(Bolt::ValidationError, /must be a String/)
    end
  end

  describe '#read_json_file with IOError' do
    it 'raises FileError on IOError' do
      allow(File).to receive(:read).and_raise(IOError, 'stream closed')
      expect {
        Bolt::Util.read_json_file('/some/path.json', 'testfile')
      }.to raise_error(Bolt::FileError, /Could not read testfile/)
    end
  end

  describe '#read_yaml_hash with IOError' do
    it 'raises FileError on IOError' do
      allow(File).to receive(:open).and_raise(IOError, 'stream closed')
      expect {
        Bolt::Util.read_yaml_hash('/some/path.yaml', 'testfile')
      }.to raise_error(Bolt::FileError, /Could not read testfile/)
    end
  end
end
