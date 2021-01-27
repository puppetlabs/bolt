# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/project'
require 'bolt_spec/task'
require 'bolt/cli'
require 'bolt/util'
require 'concurrent/utility/processor_counter'
require 'r10k/action/puppetfile/install'
require 'yaml'

describe "Bolt::CLI" do
  include BoltSpec::Files
  include BoltSpec::Project
  include BoltSpec::Task

  let(:inventory) { Bolt::Inventory.empty }
  let(:target) { inventory.get_target('foo') }

  before(:each) do
    outputter = Bolt::Outputter::Human.new(false, false, false, false, StringIO.new)

    allow_any_instance_of(Bolt::CLI).to receive(:outputter).and_return(outputter)
    allow_any_instance_of(Bolt::CLI).to receive(:warn)

    # Don't print error messages to the console
    allow($stdout).to receive(:puts)
    allow($stderr).to receive(:puts)

    # Don't allow tests to override the captured log config
    allow(Bolt::Logger).to receive(:configure)

    Logging.logger[:root].level = :info
  end

  def stub_file(path)
    stat = double('stat', readable?: true, file?: true, directory?: false)

    allow(Bolt::Util).to receive(:file_stat).with(path).and_return(stat)
  end

  def stub_non_existent_file(path)
    allow(Bolt::Util).to receive(:file_stat).with(path).and_raise(
      Errno::ENOENT, "No such file or directory @ rb_file_s_stat - #{path}"
    )
  end

  def stub_unreadable_file(path)
    stat = double('stat', readable?: false, file?: true)

    allow(Bolt::Util).to receive(:file_stat).with(path).and_return(stat)
  end

  def stub_directory(path)
    stat = double('stat', readable?: true, file?: false, directory?: true)

    allow(Bolt::Util).to receive(:file_stat).with(path).and_return(stat)
  end

  def stub_config(file_content = {})
    allow(Bolt::Util).to receive(:read_yaml_hash).and_return(file_content)
    allow(Bolt::Util).to receive(:read_optional_yaml_hash).and_return(file_content)
  end

  context 'gem install' do
    around(:each) do |example|
      original_value = ENV['BOLT_GEM']
      example.run
    ensure
      ENV['BOLT_GEM'] = original_value
    end

    it 'displays a warning when Bolt is installed as a gem' do
      ENV.delete('BOLT_GEM')

      cli = Bolt::CLI.new(%w[task show])
      allow(cli).to receive(:incomplete_install?).and_return(true)
      cli.execute(cli.parse)

      output = @log_output.readlines.join
      expect(output).to match(/Bolt may be installed as a gem/)
    end

    it 'does not display a warning when BOLT_GEM is set' do
      ENV['BOLT_GEM'] = 'true'

      cli = Bolt::CLI.new(%w[task show])
      allow(cli).to receive(:incomplete_install?).and_return(true)
      cli.execute(cli.parse)

      output = @log_output.readlines.join
      expect(output).not_to match(/Bolt may be installed as a gem/)
    end
  end

  context 'guide' do
    let(:config) { double('config', format: nil) }
    let(:topic)  { 'project' }

    context '#guides' do
      it 'returns a hash of topics and filepaths to guides' do
        expect(Dir).to receive(:children).and_return(['milo.txt'])
        cli = Bolt::CLI.new(['guide'])
        expect(cli.guides).to match(
          'milo' => %r{guides/milo.txt}
        )
      end
    end

    context '#list_topics' do
      it 'lists topics' do
        cli = Bolt::CLI.new(['guide'])
        expect(cli.outputter).to receive(:print_topics).with(cli.guides.keys)
        cli.list_topics
      end

      it 'returns 0' do
        cli = Bolt::CLI.new(['guide'])
        expect(cli.list_topics).to eq(0)
      end
    end

    context '#show_guide' do
      before(:each) do
        allow_any_instance_of(Bolt::CLI).to receive(:analytics).and_return(Bolt::Analytics::NoopClient.new)
      end

      it 'prints a guide for a known topic' do
        Tempfile.create do |file|
          content = "The trials and tribulations of Bolty McBoltface\n"
          File.write(file, content)

          cli = Bolt::CLI.new(['guide', topic])
          allow(cli).to receive(:guides).and_return(topic => file.path)

          expect(cli.outputter).to receive(:print_guide).with(content, topic)
          cli.show_guide(topic)
        end
      end

      it 'submits a known_topic analytics event' do
        cli = Bolt::CLI.new(['guide', topic])
        expect(cli.analytics).to receive(:event).with('Guide', 'known_topic', label: topic)
        cli.show_guide(topic)
      end

      it 'prints a list of topics when given an unknown topic' do
        topic = 'boltymcboltface'
        cli   = Bolt::CLI.new(['guide', topic])
        allow(cli).to receive(:config).and_return(config)
        expect(cli).to receive(:list_topics)
        expect(cli.outputter).to receive(:print_message).with(/Did not find guide for topic '#{topic}'/)
        cli.show_guide(topic)
      end

      it 'submits an uknown_topic analytics event' do
        topic = 'boltymcboltface'
        cli   = Bolt::CLI.new(['guide', topic])
        allow(cli).to receive(:config).and_return(config)
        expect(cli.analytics).to receive(:event).with('Guide', 'unknown_topic', label: topic)
        cli.show_guide(topic)
      end

      it 'returns 0' do
        cli = Bolt::CLI.new(['guide', topic])
        expect(cli.show_guide(topic)).to eq(0)
      end
    end
  end

  context 'module' do
    let(:cli)            { Bolt::CLI.new(command) }
    let(:command)        { %w[module show] }
    let(:installer)      { double('installer', add: true, install: true) }
    let(:project_config) { { 'modules' => [] } }
    let(:project)        { @project }

    around(:each) do |example|
      in_project(config: project_config) do |project|
        @project = project
        example.run
      end
    end

    before(:each) do
      allow(Bolt::ModuleInstaller).to receive(:new).and_return(installer)
    end

    context 'with modules configured' do
      it 'does not error' do
        result = cli.execute(cli.parse)
        expect(result).to eq(0)
      end
    end

    context 'add' do
      it 'errors without a module' do
        cli = Bolt::CLI.new(%w[module add])
        expect { cli.parse }.to raise_error(
          Bolt::CLIError,
          /Must specify a module name/
        )
      end

      it 'errors with multiple modules' do
        cli = Bolt::CLI.new(%w[module add foo bar])
        expect { cli.parse }.to raise_error(
          Bolt::CLIError,
          /Unknown argument/
        )
      end

      it 'runs with a single module' do
        cli = Bolt::CLI.new(%w[module add puppetlabs-yaml])
        expect(installer).to receive(:add)
        cli.execute(cli.parse)
      end

      it 'passes force' do
        cli = Bolt::CLI.new(%w[module add puppetlabs-yaml --force])

        allow(installer).to receive(:install) do |*args|
          expect(args).to include({ force: true })
        end

        cli.execute(cli.parse)
      end
    end

    context 'install' do
      let(:command)        { %w[module install] }
      let(:project_config) { { 'modules' => ['puppetlabs-yaml'] } }

      it 'errors with extra arguments' do
        cli = Bolt::CLI.new(%w[module install puppetlabs-yaml])
        command = Bolt::Util.powershell? ? 'Add-BoltModule' : 'bolt module add'
        expect { cli.parse }.to raise_error(
          Bolt::CLIError,
          /Invalid argument.*#{command}/
        )
      end

      it 'does nothing if project config has no module declarations' do
        result = cli.execute(cli.parse)
        expect(result).to eq(0)
        expect(project.puppetfile.exist?).to eq(false)
        expect(project.managed_moduledir.exist?).to eq(false)
      end

      it 'runs' do
        expect(installer).to receive(:install)
        cli.execute(cli.parse)
      end

      it 'installs project modules forcibly' do
        cli = Bolt::CLI.new(%w[module install --force])

        allow(installer).to receive(:install) do |*args|
          expect(args).to include({ force: true, resolve: nil })
        end

        cli.execute(cli.parse)
      end

      it 'install modules from Puppetfile without resolving' do
        cli = Bolt::CLI.new(%w[module install --no-resolve])

        allow(installer).to receive(:install) do |*args|
          expect(args).to include({ force: nil, resolve: false })
        end

        cli.execute(cli.parse)
      end
    end
  end

  context 'plan new' do
    let(:plan_name)    { 'project' }
    let(:config)       { { 'name' => plan_name } }
    let(:config_path)  { File.join(@project_path, 'bolt-project.yaml') }
    let(:command)      { %W[plan new #{plan_name}] }
    let(:cli)          { Bolt::CLI.new(command) }
    let(:project)      { @project }

    around(:each) do |example|
      in_project(plan_name, config: config) do |project|
        @project = project
        example.run
      end
    end

    it 'errors without a plan name' do
      cli = Bolt::CLI.new(%w[plan new])

      expect { cli.parse }.to raise_error(
        Bolt::CLIError,
        /Must specify a plan name/
      )
    end

    it 'calls PlanCreator functions' do
      expect(Bolt::PlanCreator).to receive(:validate_input)
        .with(project, plan_name)
        .and_call_original
      expect(Bolt::PlanCreator).to receive(:create_plan)
        .with(project.plans_path, plan_name, cli.outputter, nil)
        .and_call_original
      cli.execute(cli.parse)
      expect(Dir.children(project.plans_path)).to eq(["init.yaml"])
      expect(File.read(File.join(project.plans_path, "init.yaml")))
        .to eq(Bolt::PlanCreator.yaml_plan('project'))
    end

    context "with puppet flag" do
      let(:command) { %W[plan new #{plan_name} --pp] }

      it 'sets is_puppet to true when flag is present' do
        expect(Bolt::PlanCreator).to receive(:validate_input)
          .with(project, plan_name)
          .and_call_original
        expect(Bolt::PlanCreator).to receive(:create_plan)
          .with(project.plans_path, plan_name, cli.outputter, true)
          .and_call_original
        cli.execute(cli.parse)
        expect(Dir.children(project.plans_path)).to eq(["init.pp"])
        expect(File.read(File.join(project.plans_path, "init.pp")))
          .to eq(Bolt::PlanCreator.puppet_plan('project'))
      end
    end
  end

  context "without a config file" do
    let(:project) { Bolt::Project.new({}, '.') }
    before(:each) do
      allow(Bolt::Project).to receive(:find_boltdir).and_return(project)
      allow_any_instance_of(Bolt::Project).to receive(:resource_types)
      allow(Bolt::Util).to receive(:read_yaml_hash).and_return({})
      allow(Bolt::Util).to receive(:read_optional_yaml_hash).and_return({})
    end

    it "generates an error message if an unknown argument is given" do
      cli = Bolt::CLI.new(%w[command run --unknown])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /Unknown argument '--unknown'/)
    end

    it "generates an error message if an unknown subcommand is given" do
      cli = Bolt::CLI.new(%w[--targets bolt1 bolt2 command run whoami])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /'bolt2' is not a Bolt command/)
    end

    it "generates an error message if an unknown action is given" do
      cli = Bolt::CLI.new(%w[--targets bolt1 command oops whoami])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /Expected action 'oops' to be one of/)
    end

    it "generates an error message is no action is given and one is expected" do
      cli = Bolt::CLI.new(%w[--targets bolt1 command])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /Expected an action/)
    end

    it "works without an action if no action is expected" do
      cli = Bolt::CLI.new(%w[--targets bolt1 apply file.pp])
      expect {
        cli.parse
      }.not_to raise_error
    end

    describe "help" do
      it "generates help when no arguments are specified" do
        cli = Bolt::CLI.new([])
        expect {
          expect {
            cli.parse
          }.to raise_error(Bolt::CLIExit)
        }.to output(/USAGE.*bolt/m).to_stdout
      end

      it "accepts --help" do
        cli = Bolt::CLI.new(%w[--help])
        expect {
          expect {
            cli.parse
          }.to raise_error(Bolt::CLIExit)
        }.to output(/USAGE.*bolt/m).to_stdout
      end

      context 'listing actions with help' do
        it 'accepts command' do
          cli = Bolt::CLI.new(%w[help command])
          expect {
            expect {
              cli.parse
            }.to raise_error(Bolt::CLIExit)
          }.to output(/ACTIONS.*run/m).to_stdout
        end

        it 'accepts script' do
          cli = Bolt::CLI.new(%w[help script])
          expect {
            expect {
              cli.parse
            }.to raise_error(Bolt::CLIExit)
          }.to output(/ACTIONS.*run/m).to_stdout
        end

        it 'accepts task' do
          cli = Bolt::CLI.new(%w[help task])
          expect {
            expect {
              cli.parse
            }.to raise_error(Bolt::CLIExit)
          }.to output(/ACTIONS.*run.*show/m).to_stdout
        end

        it 'accepts plan' do
          cli = Bolt::CLI.new(%w[help plan])
          expect {
            expect {
              cli.parse
            }.to raise_error(Bolt::CLIExit)
          }.to output(/ACTIONS.*run.*show/m).to_stdout
        end

        it 'accepts file' do
          cli = Bolt::CLI.new(%w[help file])
          expect {
            expect {
              cli.parse
            }.to raise_error(Bolt::CLIExit)
          }.to output(/ACTIONS.*download.*upload/m).to_stdout
        end

        it 'accepts inventory' do
          cli = Bolt::CLI.new(%w[help inventory])
          expect {
            expect {
              cli.parse
            }.to raise_error(Bolt::CLIExit)
          }.to output(/ACTIONS.*show/m).to_stdout
        end

        it 'excludes invalid subcommand flags' do
          cli = Bolt::CLI.new(%w[help inventory])
          expect {
            expect {
              cli.parse
            }.to raise_error(Bolt::CLIExit)
          }.not_to output(/--private-key/).to_stdout
        end

        it 'excludes invalid subcommand action flags and help text' do
          cli = Bolt::CLI.new(%w[help plan show])
          expect {
            expect {
              cli.parse
            }.to raise_error(Bolt::CLIExit)
          }.not_to output(/\[parameters\].*nodes/m).to_stdout
        end

        it 'accepts apply' do
          cli = Bolt::CLI.new(%w[help apply])
          expect {
            expect {
              cli.parse
            }.to raise_error(Bolt::CLIExit)
          }.to output(/USAGE.*bolt apply \[manifest.pp\]/m).to_stdout
        end
      end
    end

    describe "version" do
      it "emits a version string" do
        cli = Bolt::CLI.new(%w[--version])
        expect {
          expect {
            cli.parse
          }.to raise_error(Bolt::CLIExit)
        }.to output(/\d+\.\d+\.\d+/).to_stdout
      end
    end

    describe "nodes" do
      let(:targets) { [target, Bolt::Target.new('bar')] }

      it "accepts a single node" do
        cli = Bolt::CLI.new(%w[command run uptime --targets foo])
        options = cli.parse
        cli.update_targets(options)
        expect(options).to include(targets: [target])
      end

      it "accepts multiple nodes" do
        cli = Bolt::CLI.new(%w[command run uptime --targets foo,bar])
        options = cli.parse
        cli.update_targets(options)
        expect(options).to include(targets: targets)
      end

      it "accepts multiple nodes across multiple declarations" do
        cli = Bolt::CLI.new(%w[command run uptime --targets foo,bar --targets bar,more,bars])
        options = cli.parse
        cli.update_targets(options)
        extra_targets = [Bolt::Target.new('more'), Bolt::Target.new('bars')]
        expect(options).to include(targets: targets + extra_targets)
      end

      it "reads from stdin when --targets is '-'" do
        nodes = <<~'NODES'
         foo
         bar
        NODES
        cli = Bolt::CLI.new(%w[command run uptime --targets -])
        allow($stdin).to receive(:read).and_return(nodes)
        options = cli.parse
        cli.update_targets(options)
        expect(options[:targets]).to eq(targets)
      end

      it "reads from a file when --targets starts with @" do
        nodes = <<~'NODES'
          foo
          bar
        NODES
        with_tempfile_containing('nodes-args', nodes) do |file|
          cli = Bolt::CLI.new(%W[command run uptime --targets @#{file.path}])
          options = cli.parse
          cli.update_targets(options)
          expect(options[:targets]).to eq(targets)
        end
      end

      it "strips leading and trailing whitespace" do
        nodes = "  foo\nbar  \nbaz\nqux  "
        with_tempfile_containing('nodes-args', nodes) do |file|
          cli = Bolt::CLI.new(%W[command run uptime --targets @#{file.path}])
          options = cli.parse
          cli.update_targets(options)
          extra_targets = [Bolt::Target.new('baz'), Bolt::Target.new('qux')]
          expect(options[:targets]).to eq(targets + extra_targets)
        end
      end

      it "expands tilde to a user directory when --targets starts with @" do
        expect(File).to receive(:read).with(File.join(Dir.home, 'nodes.txt')).and_return("foo\nbar\n")
        cli = Bolt::CLI.new(%w[command run uptime --targets @~/nodes.txt])
        allow(cli).to receive(:puppetdb_client)
        options = cli.parse
        cli.update_targets(options)
        expect(options[:targets]).to eq(targets)
      end

      it "generates an error message if no nodes given" do
        cli = Bolt::CLI.new(%w[command run uptime --targets])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Option '--targets' needs a parameter/)
      end

      it "generates an error message if nodes is omitted" do
        cli = Bolt::CLI.new(%w[command run uptime])
        options = cli.parse
        expect {
          cli.update_targets(options)
        }.to raise_error(Bolt::CLIError, /Command requires a targeting option/)
      end
    end

    describe "targets" do
      let(:targets) { [target, Bolt::Target.new('bar')] }

      it "reads from a file when --targets starts with @" do
        nodes = <<~'NODES'
          foo
          bar
        NODES
        with_tempfile_containing('nodes-args', nodes) do |file|
          cli = Bolt::CLI.new(%W[command run uptime --targets @#{file.path}])
          options = cli.parse
          cli.update_targets(options)
          expect(options[:targets]).to eq(targets)
        end
      end

      it "generates an error message if no targets are given" do
        cli = Bolt::CLI.new(%w[command run uptime --targets])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Option '--targets' needs a parameter/)
      end
    end

    describe "query" do
      it "accepts a query" do
        cli = Bolt::CLI.new(%w[command run id --query nodes{}])
        allow(cli).to receive(:query_puppetdb_nodes).and_return([])

        result = cli.parse
        expect(result[:query]).to eq('nodes{}')
      end

      it "resolves targets based on the query" do
        cli = Bolt::CLI.new(%w[command run id --query nodes{}])
        allow(cli).to receive(:query_puppetdb_nodes).and_return(%w[foo bar])

        targets = [Bolt::Target.new('foo'), Bolt::Target.new('bar')]

        options = cli.parse
        cli.update_targets(options)
        expect(options[:targets]).to eq(targets)
      end

      it "fails if it can't retrieve targets from PuppetDB" do
        cli = Bolt::CLI.new(%w[command run id --query nodes{}])
        puppetdb = double('puppetdb')
        allow(puppetdb).to receive(:query_certnames).and_raise(Bolt::PuppetDBError, "failed to puppetdb the nodes")
        allow(cli).to receive(:puppetdb_client).and_return(puppetdb)
        options = cli.parse

        expect { cli.update_targets(options) }
          .to raise_error(Bolt::PuppetDBError, /failed to puppetdb the nodes/)
      end

      it "fails if both --targets and --query are specified" do
        cli = Bolt::CLI.new(%w[command run id --query nodes{} --targets foo,bar])
        options = cli.parse
        expect { cli.update_targets(options) }.to raise_error(Bolt::CLIError, /Only one/)
      end
    end

    describe "user" do
      it "accepts a user" do
        cli = Bolt::CLI.new(%w[command run uptime --user root --targets foo])
        expect(cli.parse).to include(user: 'root')
      end

      it "generates an error message if no user value is given" do
        cli = Bolt::CLI.new(%w[command run uptime --targets foo --user])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Option '--user' needs a parameter/)
      end
    end

    describe "password" do
      it "accepts a password" do
        cli = Bolt::CLI.new(%w[command run uptime --password opensesame --targets foo])
        expect(cli.parse).to include(password: 'opensesame')
      end
    end

    describe "password-prompt" do
      it "prompts the user for password" do
        allow($stdin).to receive(:noecho).and_return('opensesame')
        allow($stderr).to receive(:print).with('Please enter your password: ')
        allow($stderr).to receive(:puts)
        cli = Bolt::CLI.new(%w[command run uptime --targets foo --password-prompt])
        expect(cli.parse).to include(password: 'opensesame')
      end
    end

    describe "key" do
      it "accepts a private key" do
        allow(Bolt::Util).to receive(:validate_file).and_return(true)
        path = File.expand_path('~/.ssh/google_compute_engine')
        cli = Bolt::CLI.new(%W[  command run uptime
                                 --private-key #{path}
                                 --targets foo])
        expect(cli.parse).to include('private-key': path)
        expect(cli.config.transports['ssh']['private-key']).to eq(File.expand_path(path))
      end

      it "expands private key relative to cwd" do
        allow(Bolt::Util).to receive(:validate_file).and_return(true)
        path = './ssh/google_compute_engine'
        cli = Bolt::CLI.new(%W[  command run uptime
                                 --private-key #{path}
                                 --targets foo])
        expect(cli.parse).to include('private-key': File.expand_path(path))
        expect(cli.config.transports['ssh']['private-key']).to eq(File.expand_path(path))
      end

      it "generates an error message if no key value is given" do
        cli = Bolt::CLI.new(%w[command run --targets foo --private-key])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError,
                         /Option '--private-key' needs a parameter/)
      end
    end

    describe "concurrency" do
      it "accepts a concurrency limit" do
        cli = Bolt::CLI.new(%w[command run uptime --concurrency 10 --targets foo])
        expect(cli.parse).to include(concurrency: 10)
      end

      it "defaults to 100 with sufficient ulimit" do
        cli = Bolt::CLI.new(%w[command run uptime --targets foo])
        cli.parse
        expect(cli.config.concurrency).to eq(100)
      end

      it "generates an error message if no concurrency value is given" do
        cli = Bolt::CLI.new(%w[command run uptime --targets foo --concurrency])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError,
                         /Option '--concurrency' needs a parameter/)
      end
    end

    describe "compile-concurrency" do
      it "accepts a concurrency limit" do
        cli = Bolt::CLI.new(%w[command run uptime --compile-concurrency 2 --targets foo])
        expect(cli.parse).to include('compile-concurrency': 2)
      end

      it "defaults to unset" do
        cli = Bolt::CLI.new(%w[command run uptime --targets foo])
        cli.parse
        # verifies Etc.nprocessors is the same as Concurrent.processor_count
        expect(cli.config.compile_concurrency).to eq(Concurrent.processor_count)
      end

      it "generates an error message if no concurrency value is given" do
        cli = Bolt::CLI.new(%w[command run uptime --targets foo --compile-concurrency])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError,
                         /Option '--compile-concurrency' needs a parameter/)
      end
    end

    describe "console log level" do
      it "is not sensitive to ordering of debug and verbose" do
        expect(Bolt::Logger).to receive(:configure).with(include('console' => { level: 'debug' }), true, Set.new)

        cli = Bolt::CLI.new(%w[command run uptime --targets foo --log-level debug --verbose])
        cli.parse
      end

      it "log-level sets the log option" do
        expect(Bolt::Logger).to receive(:configure).with(include('console' => { level: 'debug' }), true, Set.new)

        cli = Bolt::CLI.new(%w[command run uptime --targets foo --log-level debug])
        cli.parse
      end

      it "raises a Bolt error when the level is a stringified integer" do
        cli = Bolt::CLI.new(%w[command run uptime --targets foo --log-level 42])
        expect { cli.parse }.to raise_error(Bolt::ValidationError, /Value at 'log.console.level' must be one of/)
      end
    end

    describe "host-key-check" do
      it "accepts `--host-key-check`" do
        cli = Bolt::CLI.new(%w[command run uptime --host-key-check --targets foo])
        cli.parse
        expect(cli.config.transports['ssh']['host-key-check']).to eq(true)
      end

      it "accepts `--no-host-key-check`" do
        cli = Bolt::CLI.new(%w[command run uptime --no-host-key-check --targets foo])
        cli.parse
        expect(cli.config.transports['ssh']['host-key-check']).to eq(false)
      end

      it "defaults to nil" do
        cli = Bolt::CLI.new(%w[command run uptime --targets foo])
        cli.parse
        expect(cli.config.transports['ssh']['host-key-check']).to eq(nil)
      end
    end

    describe "connect-timeout" do
      it "accepts a specific timeout" do
        cli = Bolt::CLI.new(%w[command run uptime --connect-timeout 123 --targets foo])
        expect(cli.parse).to include('connect-timeout': 123)
      end

      it "generates an error message if no timeout value is given" do
        cli = Bolt::CLI.new(%w[command run uptime --targets foo --connect-timeout])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError,
                         /Option '--connect-timeout' needs a parameter/)
      end
    end

    describe "modulepath" do
      it "treats relative modulepath as relative to pwd" do
        site = File.expand_path('site')
        modulepath = [site, 'modules'].join(File::PATH_SEPARATOR)
        cli = Bolt::CLI.new(%W[command run uptime --modulepath #{modulepath} --targets foo])
        expect(cli.parse).to include(modulepath: [site, File.expand_path('modules')])
      end

      it "accepts shorthand -m" do
        site = File.expand_path('site')
        modulepath = [site, 'modules'].join(File::PATH_SEPARATOR)
        cli = Bolt::CLI.new(%W[command run uptime -m #{modulepath} --targets foo])
        expect(cli.parse).to include(modulepath: [site, File.expand_path('modules')])
      end

      it "generates an error message if no value is given" do
        cli = Bolt::CLI.new(%w[command run uptime --targets foo --modulepath])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError,
                         /Option '--modulepath' needs a parameter/)
      end
    end

    describe "modules" do
      let(:modules) { 'puppetlabs-apt,puppetlabs-stdlib' }
      let(:cli)     { Bolt::CLI.new(%W[project init --modules #{modules}]) }

      it 'accepts a comma-separated list of modules' do
        options = cli.parse
        expect(options[:modules]).to match([
                                             { 'name' => 'puppetlabs-apt' },
                                             { 'name' => 'puppetlabs-stdlib' }
                                           ])
      end
    end

    describe "sudo" do
      it "supports running as a user" do
        cli = Bolt::CLI.new(%w[command run --targets foo whoami --run-as root])
        expect(cli.parse[:'run-as']).to eq('root')
      end
    end

    describe "sudo-password" do
      it "accepts a password" do
        cli = Bolt::CLI.new(%w[command run uptime --sudo-password opensez --run-as alibaba --targets foo])
        expect(cli.parse).to include('sudo-password': 'opensez')
      end
    end

    describe "sudo password-prompt" do
      it "prompts the user for escalation password" do
        allow($stdin).to receive(:noecho).and_return('opensesame')
        allow($stderr).to receive(:print).with('Please enter your privilege escalation password: ')
        allow($stderr).to receive(:puts)
        cli = Bolt::CLI.new(%w[command run uptime --targets foo --sudo-password-prompt])
        expect(cli.parse).to include('sudo-password': 'opensesame')
      end
    end

    describe "filter" do
      it "raises an error when a filter has illegal characters" do
        cli = Bolt::CLI.new(%w[plan show --filter JSON])
        expect { cli.parse }.to raise_error(Bolt::CLIError, /Illegal characters in filter string/)
      end
    end

    describe "transport" do
      it "defaults to 'ssh'" do
        cli = Bolt::CLI.new(%w[command run --targets foo whoami])
        cli.parse
        expect(cli.config.transport).to eq('ssh')
      end

      it "accepts ssh" do
        cli = Bolt::CLI.new(%w[command run --transport ssh --targets foo id])
        expect(cli.parse[:transport]).to eq('ssh')
      end

      it "accepts winrm" do
        cli = Bolt::CLI.new(%w[command run --transport winrm --targets foo id])
        expect(cli.parse[:transport]).to eq('winrm')
      end

      it "accepts pcp" do
        cli = Bolt::CLI.new(%w[command run --transport pcp --targets foo id])
        expect(cli.parse[:transport]).to eq('pcp')
      end

      it "rejects invalid transports" do
        cli = Bolt::CLI.new(%w[command run --transport holodeck --targets foo id])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError,
                         /Invalid parameter specified for option '--transport': holodeck/)
      end
    end

    describe "command" do
      it "interprets whoami as the command" do
        cli = Bolt::CLI.new(%w[command run --targets foo whoami])
        expect(cli.parse[:object]).to eq('whoami')
      end

      it "errors when a command is not specified" do
        cli = Bolt::CLI.new(%w[command run --targets foo])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Must specify a command to run/)
      end

      it "errors when a command is empty string" do
        cli = Bolt::CLI.new(['command', 'run', '', '--targets', 'foo'])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Must specify a command to run/)
      end

      it "sets specified environment variables" do
        cli = Bolt::CLI.new(%w[command run --targets foo whoami --env-var POP=TARTS])
        expect(cli.parse[:env_vars]).to eq({ 'POP' => 'TARTS' })
      end

      it "reads from a file when command starts with @" do
        command = 'whoami'

        with_tempfile_containing('command', command) do |file|
          cli = Bolt::CLI.new(%W[command run @#{file.path}])
          options = cli.parse
          expect(options[:object]).to eq(command)
        end
      end

      it "reads from stdin when command is '-'" do
        command = 'whoami'

        cli = Bolt::CLI.new(%w[command run - --targets localhost])
        allow($stdin).to receive(:read).and_return(command)
        options = cli.parse
        expect(options[:object]).to eq(command)
      end
    end

    it "distinguishes subcommands" do
      cli = Bolt::CLI.new(%w[script run --targets foo])
      expect(cli.parse).to include(subcommand: 'script')
    end

    describe "file" do
      describe "upload" do
        it "uploads a file" do
          cli = Bolt::CLI.new(%w[file upload ./src /path/dest --targets foo])
          result = cli.parse
          expect(result[:object]).to eq('./src')
          expect(result[:leftovers].first).to eq('/path/dest')
        end

        it "fails with --env-var" do
          cli = Bolt::CLI.new(%w[file upload -t foo --env-var POP=ROCKS])
          expect { cli.parse }
            .to raise_error(Bolt::CLIError, /Option '--env-var' may only be specified when running a command or script/)
        end
      end

      describe "download" do
        it "downloads a file" do
          cli = Bolt::CLI.new(%w[file download /etc/ssh downloads --targets foo])
          result = cli.parse
          expect(result[:object]).to eq('/etc/ssh')
          expect(result[:leftovers].first).to eq('downloads')
        end
      end
    end

    describe "handling parameters" do
      it "returns {} if none are specified" do
        cli = Bolt::CLI.new(%w[plan run my::plan --modulepath .])
        result = cli.parse
        expect(result[:task_options]).to eq({})
      end

      it "reads params on the command line" do
        cli = Bolt::CLI.new(%w[plan run my::plan kj=2hv iuhg=iube 2whf=lcv
                               --modulepath .])
        result = cli.parse
        expect(result[:params_parsed]).to eq(false)
        expect(result[:task_options]).to eq('kj' => '2hv',
                                            'iuhg' => 'iube',
                                            '2whf' => 'lcv')
      end

      it "reads params in json with the params flag" do
        json_args = '{"kj":"2hv","iuhg":"iube","2whf":"lcv"}'
        cli = Bolt::CLI.new(['plan', 'run', 'my::plan', '--params', json_args,
                             '--modulepath', '.'])
        result = cli.parse
        expect(result[:params_parsed]).to eq(true)
        expect(result[:task_options]).to eq('kj' => '2hv',
                                            'iuhg' => 'iube',
                                            '2whf' => 'lcv')
      end

      it "raises a cli error when json parsing fails" do
        json_args = '{"k'
        cli = Bolt::CLI.new(['plan', 'run', 'my::plan', '--params', json_args])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /unexpected token/)
      end

      it "raises a cli error when specifying params both ways" do
        cli = Bolt::CLI.new(%w[plan run my::plan --params {"a":"b"} c=d
                               --modulepath .])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /not both/)
      end

      it "reads json from a file when --params starts with @" do
        json_args = '{"kj":"2hv","iuhg":"iube","2whf":"lcv"}'
        with_tempfile_containing('json-args', json_args) do |file|
          cli = Bolt::CLI.new(%W[plan run my::plan --params @#{file.path}
                                 --modulepath .])
          result = cli.parse
          expect(result[:task_options]).to eq('kj' => '2hv',
                                              'iuhg' => 'iube',
                                              '2whf' => 'lcv')
        end
      end

      it "raises a cli error when reading the params file fails" do
        Dir.mktmpdir do |dir|
          cli = Bolt::CLI.new(%W[plan run my::plan --params @#{dir}/nope
                                 --modulepath .])
          expect {
            cli.parse
          }.to raise_error(Bolt::FileError, /No such file/)
        end
      end

      it "reads json from stdin when --params is just '-'" do
        json_args = '{"kj":"2hv","iuhg":"iube","2whf":"lcv"}'
        cli = Bolt::CLI.new(%w[plan run my::plan --params - --modulepath .])
        allow($stdin).to receive(:read).and_return(json_args)
        result = cli.parse
        expect(result[:task_options]).to eq('kj' => '2hv',
                                            'iuhg' => 'iube',
                                            '2whf' => 'lcv')
      end
    end

    describe 'task' do
      it "errors without a task" do
        cli = Bolt::CLI.new(%w[task run --targets example.com --modulepath .])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Must specify/)
      end

      it "errors if task is a parameter" do
        cli = Bolt::CLI.new(%w[task run --targets example.com --modulepath . p1=v1])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Invalid task/)
      end

      it "fails show with --noop" do
        expected = "Option '--noop' may only be specified when running a task or applying manifest code"
        expect {
          cli = Bolt::CLI.new(%w[task show foo --targets bar --noop])
          cli.parse
        }.to raise_error(Bolt::CLIError, expected)
      end
    end

    describe 'plan' do
      it "errors without a plan" do
        cli = Bolt::CLI.new(%w[plan run --modulepath . nodes=example.com])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Invalid plan/)
      end

      it "errors if plan is a parameter" do
        cli = Bolt::CLI.new(%w[plan run nodes=example.com --modulepath . p1=v1])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Invalid plan/)
      end

      it "accepts targets resulting from --query from puppetdb" do
        cli = Bolt::CLI.new(%w[command run foo --query nodes{}])
        allow(cli).to receive(:query_puppetdb_nodes).once.and_return(%w[foo bar])
        targets = [Bolt::Target.new('foo'), Bolt::Target.new('bar')]
        result = cli.parse
        cli.validate(result)
        cli.execute(result)
        expect(result[:targets]).to eq(targets)
        expect(result[:target_args]).to eq(%w[foo bar])
      end

      it "fails when --targets AND --query provided" do
        expect {
          cli = Bolt::CLI.new(%w[plan run foo --query nodes{} --targets bar])
          cli.update_targets(cli.parse)
        }.to raise_error(Bolt::CLIError, /Only one targeting option/)
      end

      it "fails with --noop" do
        expected = "Option '--noop' may only be specified when running a task or applying manifest code"
        expect {
          cli = Bolt::CLI.new(%w[plan run foo --targets bar --noop])
          cli.parse
        }.to raise_error(Bolt::CLIError, expected)
      end
    end

    describe 'apply' do
      it "errors without an object or inline code" do
        expect {
          cli = Bolt::CLI.new(%w[apply --targets bar])
          cli.parse
        }.to raise_error(Bolt::CLIError, 'a manifest file or --execute is required')
      end

      it "errors with both an object and inline code" do
        expect {
          cli = Bolt::CLI.new(%w[apply foo.pp --execute hello --targets bar])
          cli.parse
        }.to raise_error(Bolt::CLIError, '--execute is unsupported when specifying a manifest file')
      end
    end

    describe "bundled_content" do
      let(:empty_content) {
        { "Plan" => [],
          "Plugin" => Bolt::Plugin::BUILTIN_PLUGINS,
          "Task" => [] }
      }
      it "does not calculate bundled content for a command" do
        cli = Bolt::CLI.new(%w[command run foo --targets bar])
        cli.parse
        expect(cli.bundled_content).to eq(empty_content)
      end

      it "does not calculate bundled content for a script" do
        cli = Bolt::CLI.new(%w[script run foo --targets bar])
        cli.parse
        expect(cli.bundled_content).to eq(empty_content)
      end

      it "does not calculate bundled content for a file" do
        cli = Bolt::CLI.new(%w[file upload /tmp /var foo --targets bar])
        cli.parse
        expect(cli.bundled_content).to eq(empty_content)
      end

      it "calculates bundled content for a task" do
        cli = Bolt::CLI.new(%w[task run foo --targets bar])
        cli.parse
        expect(cli.bundled_content['Task']).not_to be_empty
      end

      it "calculates bundled content for a plan" do
        cli = Bolt::CLI.new(%w[plan run foo --targets bar])
        cli.parse
        expect(cli.bundled_content['Plan']).not_to be_empty
        expect(cli.bundled_content['Task']).not_to be_empty
      end
    end

    describe "execute" do
      let(:executor) { double('executor', noop: false, subscribe: nil, shutdown: nil, in_parallel: false) }
      let(:cli) { Bolt::CLI.new({}) }
      let(:targets) { [target] }
      let(:output) { StringIO.new }
      let(:result_vals) { [{}] }
      let(:fail_vals) { [{ '_error' => {} }] }
      let(:result_set) do
        results = targets.zip(result_vals).map do |t, r|
          Bolt::Result.new(t, value: r)
        end
        Bolt::ResultSet.new(results)
      end

      let(:fail_set) do
        results = targets.zip(fail_vals).map do |t, r|
          Bolt::Result.new(t, value: r)
        end
        Bolt::ResultSet.new(results)
      end

      before :each do
        allow(cli).to receive(:config).and_return(Bolt::Config.default)
        allow(Bolt::Executor).to receive(:new).and_return(executor)
        allow(executor).to receive(:log_plan) { |_plan_name, &block| block.call }
        allow(executor).to receive(:run_plan) do |scope, plan, params|
          plan.call_by_name_with_scope(scope, params, true)
        end

        outputter = Bolt::Outputter::JSON.new(false, false, false, false, output)

        allow(cli).to receive(:outputter).and_return(outputter)
      end

      context 'when running a command' do
        let(:options) {
          {
            targets: targets,
            subcommand: 'command',
            action: 'run',
            object: 'whoami'
          }
        }

        it "executes the 'whoami' command" do
          expect(executor)
            .to receive(:run_command)
            .with(targets, 'whoami', kind_of(Hash))
            .and_return(Bolt::ResultSet.new([]))

          expect(cli.execute(options)).to eq(0)
          expect(JSON.parse(output.string)).to be
        end

        it "returns 2 if any node fails" do
          expect(executor)
            .to receive(:run_command)
            .with(targets, 'whoami', kind_of(Hash))
            .and_return(fail_set)

          expect(cli.execute(options)).to eq(2)
        end
      end

      context "when running a script" do
        let(:script) { 'bar.sh' }
        let(:options) {
          { targets: targets, subcommand: 'script', action: 'run', object: script,
            leftovers: [] }
        }

        it "runs a script" do
          stub_file(script)

          expect(executor)
            .to receive(:run_script)
            .with(targets, script, [], kind_of(Hash))
            .and_return(Bolt::ResultSet.new([]))

          expect(cli.execute(options)).to eq(0)
          expect(JSON.parse(output.string)).to be
        end

        it "errors for non-existent scripts" do
          stub_non_existent_file(script)

          expect { cli.execute(options) }.to raise_error(
            Bolt::FileError, /The script '#{script}' does not exist/
          )
          expect(JSON.parse(output.string)).to be
        end

        it "errors for unreadable scripts" do
          stub_unreadable_file(script)

          expect { cli.execute(options) }.to raise_error(
            Bolt::FileError, /The script '#{script}' is unreadable/
          )
          expect(JSON.parse(output.string)).to be
        end

        it "errors for scripts that aren't files" do
          stub_directory(script)

          expect { cli.execute(options) }.to raise_error(
            Bolt::FileError, /The script '#{script}' is not a file/
          )
          expect(JSON.parse(output.string)).to be
        end

        it "returns 2 if any node fails" do
          stub_file(script)
          expect(executor).to receive(:run_script)
            .with(targets, script, [], kind_of(Hash))
            .and_return(fail_set)

          expect(cli.execute(options)).to eq(2)
        end
      end

      context "when showing available tasks", :reset_puppet_settings do
        before :each do
          cli.config.modulepath = fixtures_path('modules')
          cli.config.format = 'json'
        end

        it "lists tasks with description" do
          options = {
            subcommand: 'task',
            action: 'show'
          }
          cli.execute(options)
          tasks = JSON.parse(output.string)['tasks']
          [
            ['sample', nil],
            ['sample::echo', nil],
            ['sample::no_noop', 'Task with no noop'],
            ['sample::noop', 'Task with noop'],
            ['sample::notice', nil],
            ['sample::params', 'Task with parameters'],
            ['sample::ps_noop', 'Powershell task with noop'],
            ['sample::stdin', nil],
            ['sample::winstdin', nil]
          ].each do |taskdoc|
            expect(tasks).to include(taskdoc)
          end
        end

        it "only includes tasks set in bolt-project.yaml" do
          mocks = {
            type: '',
            resource_types: '',
            tasks: ['facts'],
            project_file?: true,
            load_as_module?: true,
            name: nil,
            plans_path: '',
            to_h: {}
          }
          proj = double('project', mocks)
          allow(cli.config).to receive(:project).and_return(proj)
          options = {
            subcommand: 'task',
            action: 'show'
          }
          cli.execute(options)
          tasks = JSON.parse(output.string)['tasks']
          expect(tasks).to eq([['facts', "Gather system facts"]])
        end

        it "lists modulepath" do
          options = {
            subcommand: 'task',
            action: 'show'
          }
          cli.execute(options)
          modulepath = JSON.parse(output.string)['modulepath']
          expect(modulepath).to include(fixtures_path('modules'))
        end

        it "shows an individual task data" do
          task_name = 'sample::params'
          options = {
            subcommand: 'task',
            action: 'show',
            object: task_name
          }
          cli.execute(options)
          json = JSON.parse(output.string)
          json.delete("files")
          expect(json).to eq(
            "name" => "sample::params",
            "module_dir" => fixtures_path('modules', 'sample'),
            "metadata" => {
              "anything" => true,
              "description" => "Task with parameters",
              "extensions" => {},
              "input_method" => 'stdin',
              "parameters" => {
                "mandatory_string" => {
                  "description" => "Mandatory string parameter",
                  "type" => "String[1, 10]"
                },
                "mandatory_integer" => {
                  "description" => "Mandatory integer parameter",
                  "type" => "Integer"
                },
                "mandatory_boolean" => {
                  "description" => "Mandatory boolean parameter",
                  "type" => "Boolean"
                },
                "non_empty_string" => {
                  "type" => "String[1]"
                },
                "optional_string" => {
                  "description" => "Optional string parameter",
                  "type" => "Optional[String]"
                },
                "optional_integer" => {
                  "description" => "Optional integer parameter",
                  "type" => "Optional[Integer[-5,5]]"
                },
                "no_type" => {
                  "description" => "A parameter without a type"
                }
              },
              "supports_noop" => true
            }
          )
        end

        it "does not load inventory" do
          options = {
            subcommand: 'task',
            action: 'show'
          }

          expect(cli).not_to receive(:inventory)

          cli.execute(options)
        end
      end

      context "when available tasks include an error", :reset_puppet_settings do
        before :each do
          cli.config.modulepath = fixtures_path('invalid_mods')
          cli.config.format = 'json'
        end

        it "task show prints a warning but shows other valid tasks" do
          options = {
            subcommand: 'task',
            action: 'show'
          }
          cli.execute(options)
          json = JSON.parse(output.string)['tasks']
          tasks = [
            ["package", "Manage and inspect the state of packages"],
            ["service", "Manage and inspect the state of services"]
          ]
          tasks.each do |task|
            expect(json).to include(task)
          end
          output = @log_output.readlines.join
          expect(output).to match(/unexpected token/)
        end
      end

      context "when the task is not in the modulepath", :reset_puppet_settings do
        before :each do
          cli.config.modulepath = fixtures_path('modules')
        end

        it "task show displays an error" do
          options = {
            subcommand: 'task',
            action: 'show',
            object: 'abcdefg'
          }
          expect {
            cli.execute(options)
          }.to raise_error(
            Bolt::Error,
            /Could not find a task named 'abcdefg'/
          )
        end
      end

      context "when showing available plans", :reset_puppet_settings do
        before :each do
          cli.config.modulepath = fixtures_path('modules')
          cli.config.format = 'json'
        end

        it "lists plans" do
          options = {
            subcommand: 'plan',
            action: 'show'
          }
          cli.execute(options)
          plan_list = JSON.parse(output.string)['plans']
          [
            ['sample'],
            ['sample::single_task'],
            ['sample::three_tasks'],
            ['sample::two_tasks'],
            ['sample::yaml']
          ].each do |plan|
            expect(plan_list).to include(plan)
          end
        end

        it "lists modulepath" do
          options = {
            subcommand: 'plan',
            action: 'show'
          }
          cli.execute(options)
          modulepath = JSON.parse(output.string)['modulepath']
          expect(modulepath).to include(fixtures_path('modules'))
        end

        it "shows an individual plan data" do
          plan_name = 'sample::optional_params_task'
          options = {
            subcommand: 'plan',
            action: 'show',
            object: plan_name
          }
          cli.execute(options)
          json = JSON.parse(output.string)
          expect(json).to eq(
            "name" => "sample::optional_params_task",
            "description" => "Demonstrates plans with optional parameters",
            "module_dir" => fixtures_path('modules', 'sample'),
            "parameters" => {
              "param_mandatory" => {
                "type" => "String",
                "description" => "A mandatory parameter",
                "sensitive" => false
              },
              "param_optional" => {
                "type" => "Optional[String]",
                "description" => "An optional parameter",
                "sensitive" => false
              },
              "param_with_default_value" => {
                "type" => "String",
                "description" => "A parameter with a default value",
                "default_value" => "'foo'",
                "sensitive" => false
              }
            }
          )
        end

        it "warns when yard doc parameters do not match the plan signature parameters" do
          plan_name = 'sample::documented_param_typo'
          options = {
            subcommand: 'plan',
            action: 'show',
            object: plan_name
          }
          cli.execute(options)
          json = JSON.parse(output.string)
          expect(json).to eq(
            "name" => plan_name,
            "module_dir" => fixtures_path('modules', 'sample'),
            "description" => nil,
            "parameters" => {
              "oops" => {
                "type" => "String",
                "default_value" => "typo",
                "sensitive" => false
              }
            }
          )
          expected_log = /parameter 'not_oops' does not exist.*sample::documented_param_typo/m
          expect(@log_output.readlines.join).to match(expected_log)
        end

        it "shows an individual yaml plan data" do
          plan_name = 'sample::yaml'
          options = {
            subcommand: 'plan',
            action: 'show',
            object: plan_name
          }
          cli.execute(options)
          json = JSON.parse(output.string)
          expect(json).to eq(
            "name" => "sample::yaml",
            "description" => nil,
            "module_dir" => fixtures_path('modules', 'sample'),
            "parameters" => {
              "nodes" => {
                "type" => "TargetSpec",
                "sensitive" => false
              },
              "param_optional" => {
                "type" => "Optional[String]",
                "default_value" => 'undef',
                "sensitive" => false
              },
              "param_with_default_value" => {
                "type" => "String",
                "default_value" => 'hello',
                "sensitive" => false
              }
            }
          )
        end

        it "does not load inventory" do
          options = {
            subcommand: 'plan',
            action: 'show'
          }

          expect(cli).not_to receive(:inventory)

          cli.execute(options)
        end
      end

      context "when available plans include an error", :reset_puppet_settings do
        before :each do
          cli.config.modulepath = fixtures_path('invalid_mods')
          cli.config.format = 'json'
        end

        it "plan show prints a warning but shows other valid plans" do
          options = {
            subcommand: 'plan',
            action: 'show'
          }

          cli.execute(options)
          json = JSON.parse(output.string)['plans']
          expect(json).to include(["aggregate::count"],
                                  ["aggregate::targets"],
                                  ["canary"],
                                  ["facts"],
                                  ["facts::info"],
                                  ["puppetdb_fact"],
                                  ["sample::ok"])

          expect(@log_output.readlines.join).to match(/Syntax error at.*single_task.pp/m)
        end

        it "plan run displays an error" do
          plan_name = 'sample::single_task'
          plan_params = { 'nodes' => targets.map(&:host).join(',') }

          options = {
            nodes: [],
            subcommand: 'plan',
            action: 'run',
            object: plan_name,
            task_options: plan_params
          }
          expect { cli.execute(options) }.to raise_error(/^Syntax error at/)
        end
      end

      context "when the plan is not in the modulepath", :reset_puppet_settings do
        before :each do
          cli.config.modulepath = fixtures_path('modules')
        end

        it "plan show displays an error" do
          options = {
            subcommand: 'plan',
            action: 'show',
            object: 'abcdefg'
          }
          expect {
            cli.execute(options)
          }.to raise_error(
            Bolt::Error,
            /Could not find a plan named 'abcdefg'/
          )
        end
      end

      context "when running a task", :reset_puppet_settings do
        let(:task_name) { +'sample::echo' }
        let(:task_params) { { 'message' => 'hi' } }
        let(:options) {
          {
            targets: targets,
            subcommand: 'task',
            action: 'run',
            object: task_name,
            task_options: task_params,
            params_parsed: true
          }
        }
        let(:input_method) { nil }
        let(:task_path) { +'modules/sample/tasks/echo.sh$' }
        let(:task_t) { task_type(task_name, Regexp.new(task_path), input_method) }

        before :each do
          allow(executor).to receive(:report_bundled_content)
          cli.config.modulepath = fixtures_path('modules')
        end

        it "runs a task given a name" do
          expect(executor)
            .to receive(:run_task)
            .with(targets, task_t, task_params, kind_of(Hash), [])
            .and_return(Bolt::ResultSet.new([]))
          expect(cli.execute(options)).to eq(0)
          expect(JSON.parse(output.string)).to be
        end

        it "returns 2 if any node fails" do
          expect(executor)
            .to receive(:run_task)
            .with(targets, task_t, task_params, kind_of(Hash), [])
            .and_return(fail_set)

          expect(cli.execute(options)).to eq(2)
        end

        it "errors for non-existent modules" do
          task_name.replace 'dne::task1'

          expect { cli.execute(options) }.to raise_error(
            Bolt::Error, /Could not find a task named 'dne::task1'/
          )
          expect(JSON.parse(output.string)).to be
        end

        it "errors for non-existent tasks" do
          task_name.replace 'sample::dne'

          expect { cli.execute(options) }.to raise_error(
            Bolt::Error, /Could not find a task named 'sample::dne'/
          )
          expect(JSON.parse(output.string)).to be
        end

        it "raises errors from the executor" do
          task_params.clear

          expect(executor)
            .to receive(:run_task)
            .with(targets, task_t, {}, kind_of(Hash), [])
            .and_raise("Could not connect to target")

          expect { cli.execute(options) }.to raise_error(/Could not connect to target/)
        end

        it "runs an init task given a module name" do
          task_name.replace 'sample'
          task_path.replace 'modules/sample/tasks/init.sh$'

          expect(executor)
            .to receive(:run_task)
            .with(targets, task_t, task_params, kind_of(Hash), [])
            .and_return(Bolt::ResultSet.new([]))

          cli.execute(options)
          expect(JSON.parse(output.string)).to be
        end

        context "input_method stdin" do
          let(:input_method) { 'stdin' }
          it "runs a task passing input on stdin" do
            task_name.replace 'sample::stdin'
            task_path.replace 'modules/sample/tasks/stdin.sh$'

            expect(executor)
              .to receive(:run_task)
              .with(targets, task_t, task_params, kind_of(Hash), [])
              .and_return(Bolt::ResultSet.new([]))

            cli.execute(options)
            expect(JSON.parse(output.string)).to be
          end

          it "runs a powershell task passing input on stdin" do
            task_name.replace 'sample::winstdin'
            task_path.replace 'modules/sample/tasks/winstdin.ps1$'

            expect(executor)
              .to receive(:run_task)
              .with(targets, task_t, task_params, kind_of(Hash), [])
              .and_return(Bolt::ResultSet.new([]))

            cli.execute(options)
            expect(JSON.parse(output.string)).to be
          end
        end

        describe 'task parameters validation' do
          let(:task_name) { +'sample::params' }
          let(:task_params) { {} }
          let(:input_method) { +'stdin' }
          let(:task_path) { %r{modules/sample/tasks/params.sh$} }

          it "errors when unknown parameters are specified" do
            task_params.merge!(
              'foo' => 'one',
              'bar' => 'two'
            )

            expect { cli.execute(options) }.to raise_error(
              Bolt::PAL::PALError,
              %r{Task sample::params:\n(?x:
               )\s*has no parameter named 'foo'\n(?x:
               )\s*has no parameter named 'bar'}
            )
            expect(JSON.parse(output.string)).to be
          end

          it "errors when required parameters are not specified" do
            task_params['mandatory_string'] = 'str'

            expect { cli.execute(options) }.to raise_error(
              Bolt::PAL::PALError,
              %r{Task sample::params:\n(?x:
               )\s*expects a value for parameter 'mandatory_integer'\n(?x:
               )\s*expects a value for parameter 'mandatory_boolean'}
            )
            expect(JSON.parse(output.string)).to be
          end

          it "errors when the specified parameter values don't match the expected data types" do
            task_params.merge!(
              'mandatory_string' => 'str',
              'mandatory_integer' => 10,
              'mandatory_boolean' => 'str',
              'non_empty_string' => 'foo',
              'optional_string' => 10
            )

            expect { cli.execute(options) }.to raise_error(
              Bolt::PAL::PALError,
              %r{Task sample::params:\n(?x:
               )\s*parameter 'mandatory_boolean' expects a Boolean value, got String\n(?x:
               )\s*parameter 'optional_string' expects a value of type Undef or String,(?x:
                                             ) got Integer}
            )
            expect(JSON.parse(output.string)).to be
          end

          it "errors when the specified parameter values are outside of the expected ranges" do
            task_params.merge!(
              'mandatory_string' => '0123456789a',
              'mandatory_integer' => 10,
              'mandatory_boolean' => true,
              'non_empty_string' => 'foo',
              'optional_integer' => 10
            )

            expect { cli.execute(options) }.to raise_error(
              Bolt::PAL::PALError,
              %r{Task sample::params:\n(?x:
               )\s*parameter 'mandatory_string' expects a String\[1, 10\] value, got String\n(?x:
               )\s*parameter 'optional_integer' expects a value of type Undef or Integer\[-5, 5\],(?x:
                                              ) got Integer\[10, 10\]}
            )
            expect(JSON.parse(output.string)).to be
          end

          it "runs the task when the specified parameters are successfully validated" do
            expect(executor)
              .to receive(:run_task)
              .with(targets, task_t, task_params, kind_of(Hash), [])
              .and_return(Bolt::ResultSet.new([]))
            task_params.merge!(
              'mandatory_string' => ' ',
              'mandatory_integer' => 0,
              'mandatory_boolean' => false,
              'non_empty_string' => 'foo'
            )

            cli.execute(options)
            expect(JSON.parse(output.string)).to be
          end

          context "using the pcp transport with invalid tasks" do
            let(:task_params) {
              # these are not legal parameters for the 'sample::params' task
              # according to the local task definition
              {
                'foo' => 'foo',
                'bar' => 'bar'
              }
            }

            context "when some targets don't use the PCP transport" do
              it "errors as usual if the task is not available locally" do
                task_name.replace 'unknown::task'

                expect { cli.execute(options) }.to raise_error(
                  Bolt::Error, /Could not find a task named 'unknown::task'/
                )
                expect(JSON.parse(output.string)).to be
              end

              it "errors as usual if invalid (according to the local task definition) parameters are specified" do
                expect { cli.execute(options) }.to raise_error(
                  Bolt::PAL::PALError,
                  %r{Task sample::params:\n(?x:
                   )\s*has no parameter named 'foo'\n(?x:
                   )\s*has no parameter named 'bar'}
                )
                expect(JSON.parse(output.string)).to be
              end
            end

            context "when all targets use the PCP transport" do
              let(:target) { inventory.get_target('pcp://foo') }
              let(:task_t) { task_type(task_name, /\A\z/, nil) }

              it "runs the task even when it is not installed locally" do
                task_name.replace 'unknown::task'

                expect(executor)
                  .to receive(:run_task)
                  .with(targets, task_t, task_params, kind_of(Hash), [])
                  .and_return(Bolt::ResultSet.new([]))

                cli.execute(options)
                expect(JSON.parse(output.string)).to be
              end

              it "runs the task even when invalid (according to the local task definition) parameters are specified" do
                expect(executor)
                  .to receive(:run_task)
                  .with(targets, task_t, task_params, kind_of(Hash), [])
                  .and_return(Bolt::ResultSet.new([]))

                cli.execute(options)
                expect(JSON.parse(output.string)).to be
              end
            end
          end
        end
      end

      context "when running a plan", :reset_puppet_settings do
        let(:plan_name) { +'sample::single_task' }
        let(:plan_params) { { 'nodes' => targets.map(&:host).join(',') } }
        let(:options) {
          {
            targets: [],
            subcommand: 'plan',
            action: 'run',
            object: plan_name,
            task_options: plan_params
          }
        }
        let(:task_t) { task_type('sample::echo', %r{modules/sample/tasks/echo.sh$}, nil) }

        before :each do
          allow(executor).to receive(:report_function_call)
          allow(executor).to receive(:report_bundled_content)
          cli.config.modulepath = fixtures_path('modules')
        end

        context 'with TargetSpec $nodes plan param' do
          it "uses the nodes passed using the --targets option(s) as the 'nodes' plan parameter" do
            plan_params.clear
            options[:targets] = targets.map(&:host)

            expect(executor)
              .to receive(:run_task)
              .with(targets, task_t, { 'message' => 'hi there' }, kind_of(Hash), kind_of(Array))
              .and_return(Bolt::ResultSet.new([Bolt::Result.for_task(target, 'yes', '', 0, 'some_task', [])]))

            expect(executor).to receive(:start_plan)
            expect(executor).to receive(:log_plan)
            expect(executor).to receive(:run_plan)
            expect(executor).to receive(:finish_plan)

            cli.execute(options)

            expect(JSON.parse(output.string)).to eq(
              [{ 'target' => 'foo',
                 'status' => 'success',
                 'action' => 'task',
                 'object' => 'some_task',
                 'value' => { '_output' => 'yes' } }]
            )
          end
        end

        context 'with TargetSpec $targets plan param' do
          let(:plan_name) { 'sample::single_task_targets' }
          it "uses the nodes passed using the --targets option(s) as the 'targets' plan parameter" do
            plan_params.clear
            options[:targets] = targets.map(&:host)

            expect(executor)
              .to receive(:run_task)
              .with(targets, task_t, { 'message' => 'hi there' }, kind_of(Hash), kind_of(Array))
              .and_return(Bolt::ResultSet.new([Bolt::Result.for_task(target, 'yes', '', 0, 'some_task', [])]))

            expect(executor).to receive(:start_plan)
            expect(executor).to receive(:log_plan)
            expect(executor).to receive(:run_plan)
            expect(executor).to receive(:finish_plan)

            cli.execute(options)

            expect(JSON.parse(output.string)).to eq(
              [{ 'target' => 'foo',
                 'status' => 'success',
                 'action' => 'task',
                 'object' => 'some_task',
                 'value' => { '_output' => 'yes' } }]
            )
          end
        end

        it "errors when the --targets option(s) and the 'targets' plan parameter are both specified" do
          options[:targets] = targets.map(&:host)
          options[:task_options] = { 'targets' => targets.map(&:host).join(',') }
          regex = /A plan's 'targets' parameter may be specified using the --targets option/
          expect { cli.execute(options) }.to raise_error(regex)
        end

        it "errors when the --targets option(s) and the 'targets' plan parameter are both specified" do
          options[:targets] = targets.map(&:host)
          options[:task_options] = { 'targets' => targets.map(&:host).join(',') }
          regex = /A plan's 'targets' parameter may be specified using the --targets option/
          expect { cli.execute(options) }.to raise_error(regex)
        end

        context "when a plan has both $targets and $nodes neither is populated with --targets" do
          let(:plan_name) { 'sample::targets_nodes' }
          it "warns when --targets does not populate both $targets and $nodes" do
            plan_params.clear
            options[:targets] = targets.map(&:host)

            expect(executor).to receive(:start_plan)
            expect(executor).to receive(:log_plan)
            expect(executor).to receive(:run_plan)
            expect(executor).to receive(:finish_plan)

            cli.execute(options)
            regex = /Plan parameters include both 'nodes' and 'targets' with type 'TargetSpec'/
            expect(@log_output.readlines.join).to match(regex)
          end
        end

        it "formats results of a passing task" do
          expect(executor)
            .to receive(:run_task)
            .with(targets, task_t, { 'message' => 'hi there' }, kind_of(Hash), [/single_task.pp/, 9])
            .and_return(Bolt::ResultSet.new([Bolt::Result.for_task(target, 'yes', '', 0, 'some_task', [])]))

          expect(executor).to receive(:start_plan)
          expect(executor).to receive(:log_plan)
          expect(executor).to receive(:run_plan)
          expect(executor).to receive(:finish_plan)

          cli.execute(options)
          expect(JSON.parse(output.string)).to eq(
            [{ 'target' => 'foo',
               'status' => 'success',
               'action' => 'task',
               'object' => 'some_task',
               'value' => { '_output' => 'yes' } }]
          )
        end

        it "raises errors from the executor" do
          expect(executor)
            .to receive(:run_task)
            .with(targets, task_t, { 'message' => 'hi there' }, kind_of(Hash), [/single_task.pp/, 9])
            .and_raise("Could not connect to target")

          expect(executor).to receive(:start_plan)
          expect(executor).to receive(:log_plan)
          expect(executor).to receive(:run_plan)
          expect(executor).to receive(:finish_plan)

          expect(cli.execute(options)).to eq(1)
          expect(JSON.parse(output.string)['msg']).to match(/Could not connect to target/)
        end

        it "formats results of a failing task" do
          expect(executor)
            .to receive(:run_task)
            .with(targets, task_t, { 'message' => 'hi there' }, kind_of(Hash), kind_of(Array))
            .and_return(Bolt::ResultSet.new([Bolt::Result.for_task(target, 'no', '', 1, 'some_task', ['/fail', 2])]))

          expect(executor).to receive(:start_plan)
          expect(executor).to receive(:log_plan)
          expect(executor).to receive(:run_plan)
          expect(executor).to receive(:finish_plan)

          cli.execute(options)
          expect(JSON.parse(output.string)).to eq(
            [
              {
                'target' => 'foo',
                'status' => 'failure',
                'action' => 'task',
                'object' => 'some_task',
                'value' => {
                  "_output" => "no",
                  "_error" => {
                    "msg" => "The task failed with exit code 1",
                    "kind" => "puppetlabs.tasks/task-error",
                    "details" => { "exit_code" => 1,
                                   "file" => "/fail",
                                   "line" => 2 },
                    "issue_code" => "TASK_ERROR"
                  }
                }
              }
            ]
          )
        end

        it "errors for non-existent plans" do
          plan_name.replace 'sample::dne'

          expect(executor).to receive(:start_plan)
          expect(executor).to receive(:finish_plan)

          expect(cli.execute(options)).to eq(1)
          expect(JSON.parse(output.string)['msg']).to match(/Could not find a plan named 'sample::dne'/)
        end
      end

      describe "file uploading" do
        let(:source) { '/path/to/local' }
        let(:dest) { '/path/to/remote' }
        let(:options) {
          {
            targets: targets,
            subcommand: 'file',
            action: 'upload',
            object: source,
            leftovers: [dest]
          }
        }

        it "uploads a file via scp" do
          stub_file(source)

          expect(executor)
            .to receive(:upload_file)
            .with(targets, source, dest, kind_of(Hash))
            .and_return(Bolt::ResultSet.new([]))

          cli.execute(options)
          expect(JSON.parse(output.string)).to be
        end

        it "uploads a directory via scp" do
          stub_directory(source)
          allow(Dir).to receive(:foreach).with(source)

          expect(executor)
            .to receive(:upload_file)
            .with(targets, source, dest, kind_of(Hash))
            .and_return(Bolt::ResultSet.new([]))

          cli.execute(options)
          expect(JSON.parse(output.string)).to be
        end

        it "returns 2 if any node fails" do
          stub_file(source)

          expect(executor)
            .to receive(:upload_file)
            .with(targets, source, dest, kind_of(Hash))
            .and_return(fail_set)

          expect(cli.execute(options)).to eq(2)
        end

        it "raises if the local file doesn't exist" do
          stub_non_existent_file(source)

          expect { cli.execute(options) }.to raise_error(
            Bolt::FileError, /The source file '#{source}' does not exist/
          )
          expect(JSON.parse(output.string)).to be
        end

        it "errors if the local file is unreadable" do
          stub_unreadable_file(source)

          expect { cli.execute(options) }.to raise_error(
            Bolt::FileError, /The source file '#{source}' is unreadable/
          )
          expect(JSON.parse(output.string)).to be
        end

        it "errors if a file in a subdirectory is unreadable" do
          child_file = File.join(source, 'afile')
          stub_directory(source)
          stub_unreadable_file(child_file)
          allow(Dir).to receive(:foreach).with(source).and_yield('afile')

          expect { cli.execute(options) }.to raise_error(
            Bolt::FileError, /The source file '#{child_file}' is unreadable/
          )
          expect(JSON.parse(output.string)).to be
        end
      end
    end

    describe "execute with noop" do
      let(:executor) { double('executor', noop: true, subscribe: nil, shutdown: nil, in_parallel: false) }
      let(:cli) { Bolt::CLI.new({}) }
      let(:targets) { [target] }
      let(:output) { StringIO.new }
      let(:bundled_content) { ['test'] }

      before :each do
        allow(cli).to receive(:bundled_content).and_return(bundled_content)
        expect(Bolt::Executor).to receive(:new).with(Bolt::Config.default.concurrency,
                                                     anything,
                                                     true,
                                                     anything).and_return(executor)

        plugins = Bolt::Plugin.setup(Bolt::Config.default, nil)
        allow(cli).to receive(:plugins).and_return(plugins)

        outputter = Bolt::Outputter::JSON.new(false, false, false, false, output)
        allow(cli).to receive(:outputter).and_return(outputter)
        allow(executor).to receive(:report_bundled_content)
        allow(cli).to receive(:config).and_return(Bolt::Config.default)
      end

      context "when running a task", :reset_puppet_settings do
        let(:task_name) { +'sample::noop' }
        let(:task_params) { { 'message' => 'hi' } }
        let(:options) {
          {
            targets: targets,
            subcommand: 'task',
            action: 'run',
            object: task_name,
            task_options: task_params,
            noop: true
          }
        }
        let(:task_t) { task_type(task_name, %r{modules/sample/tasks/noop.sh$}, nil) }

        before :each do
          cli.config.modulepath = fixtures_path('modules')
        end

        it "runs a task that supports noop" do
          expect(executor)
            .to receive(:run_task)
            .with(targets, task_t, task_params.merge('_noop' => true), kind_of(Hash), kind_of(Array))
            .and_return(Bolt::ResultSet.new([]))

          cli.execute(options)
          expect(JSON.parse(output.string)).to be
        end

        it "errors on a task that doesn't support noop" do
          task_name.replace 'sample::no_noop'

          expect(executor).not_to receive(:run_task)

          expect { cli.execute(options) }.to raise_error('Task does not support noop')
        end

        it "errors on a task without metadata" do
          task_name.replace 'sample::echo'

          expect(executor).not_to receive(:run_task)

          expect { cli.execute(options) }.to raise_error('Task does not support noop')
        end
      end
    end

    describe "installing modules" do
      let(:output)         { StringIO.new }
      let(:puppetfile)     { project.puppetfile }
      let(:modulepath)     { project.modulepath.first.to_s }
      let(:action_stub)    { double('r10k_action_puppetfile_install') }
      let(:cli)            { Bolt::CLI.new(%w[module install]) }
      let(:project_config) { { 'modules' => ['puppetlabs-yaml'] } }
      let(:project)        { @project }

      before :each do
        allow(cli).to receive(:outputter)
          .and_return(Bolt::Outputter::JSON.new(false, false, false, false, output))
        allow_any_instance_of(Bolt::PAL).to receive(:generate_types)
        allow(R10K::Action::Puppetfile::Install).to receive(:new).and_return(action_stub)
      end

      around(:each) do |example|
        in_project(config: project_config) do |project|
          @project = project
          example.run
        end
      end

      it 'installs to .modules' do
        expect(R10K::Action::Puppetfile::Install).to receive(:new)
          .with({ root: File.dirname(puppetfile),
                  puppetfile: puppetfile.to_s,
                  moduledir: project.managed_moduledir.to_s }, nil)

        allow(action_stub).to receive(:call).and_return(true)

        cli.execute(cli.parse)
      end

      it 'returns 0 and prints a result if successful' do
        allow(action_stub).to receive(:call).and_return(true)

        expect(cli.execute(cli.parse)).to eq(0)

        result = JSON.parse(output.string)
        expect(result['success']).to eq(true)
        expect(result['puppetfile']).to eq(puppetfile.to_s)
        expect(result['moduledir']).to eq(project.managed_moduledir.to_s)
      end

      it 'returns 1 and prints a result if unsuccessful' do
        allow(action_stub).to receive(:call).and_return(false)

        expect(cli.execute(cli.parse)).to eq(1)

        result = JSON.parse(output.string)
        expect(result['success']).to eq(false)
        expect(result['puppetfile']).to eq(puppetfile.to_s)
        expect(result['moduledir']).to eq(project.managed_moduledir.to_s)
      end

      it 'propagates any r10k errors' do
        allow(action_stub).to receive(:call).and_raise(R10K::Error.new('everything is terrible'))

        expect do
          cli.execute(cli.parse)
        end.to raise_error(Bolt::PuppetfileError, /everything is terrible/)
      end

      it 'lists modules in the puppetfile' do
        allow(cli).to receive(:outputter)
          .and_return(Bolt::Outputter::Human.new(false, false, false, false, output))
        cli.parse
        modules = cli.list_modules
        expect(modules.keys.first).to match(/bolt-modules/)
        expect(modules.values.first.map { |h| h[:name] }).to eq(%w[boltlib ctrl dir file out prompt system])
        expect(modules.values[1].map { |h| h[:name] })
          .to include("aggregate", "canary", "puppetdb_fact", "puppetlabs/yaml")
      end
    end

    describe "applying Puppet code" do
      let(:options) {
        {
          subcommand: 'apply',
          targets: 'foo'
        }
      }
      let(:output) { StringIO.new }
      let(:cli) { Bolt::CLI.new([]) }

      before :each do
        allow(cli).to receive(:outputter)
          .and_return(Bolt::Outputter::JSON.new(false, false, false, false, output))
        allow(cli).to receive(:config).and_return(Bolt::Config.default)
      end

      it 'fails if the code file does not exist' do
        manifest = Tempfile.new
        options[:object] = manifest.path
        manifest.close
        manifest.delete
        expect(cli).not_to receive(:apply_manifest)
        expect { cli.execute(options) }.to raise_error(Bolt::FileError)
      end
    end
  end

  describe 'BOLT_PROJECT' do
    let(:bolt_project) { '/bolt/project' }
    let(:pathname)     { Pathname.new(bolt_project).expand_path }

    around(:each) do |example|
      original = ENV['BOLT_PROJECT']
      ENV['BOLT_PROJECT'] = bolt_project
      example.run
    ensure
      ENV['BOLT_PROJECT'] = original
    end

    before(:each) do
      allow(Bolt::Util).to receive(:validate_file).and_return(true)
    end

    it 'loads from BOLT_PROJECT environment variable over --project' do
      cli = Bolt::CLI.new(%w[command run uptime --project /foo/bar --targets foo])
      cli.parse

      expect(cli.config.project.path).to eq(pathname)
    end
  end

  describe 'project' do
    let(:configdir)     { fixtures_path('configs', 'default') }
    let(:modulepath)    { [File.expand_path('/foo/bar'), File.expand_path('/baz/qux')] }
    let(:config_flags)  { %w[--targets foo --no-ssl --no-host-key-check] }
    let(:project_config) do
      { 'modulepath' => modulepath.join(File::PATH_SEPARATOR),
        'concurrency' => 14,
        'compile-concurrency' => 2,
        'format' => 'json',
        'log' => {
          'console' => {
            'level' => 'warn'
          },
          File.join(configdir, 'debug.log') => {
            'level' => 'debug',
            'append' => false
          }
        } }
    end

    let(:inventory) do
      { 'config' => {
        'ssh' => {
          'private-key' => '/bar/foo',
          'host-key-check' => false,
          'connect-timeout' => 4,
          'run-as' => 'Fakey McFakerson'
        },
        'winrm' => {
          'connect-timeout' => 7,
          'cacert' => '/path/to/winrm-cacert',
          'extensions' => ['.py', '.bat'],
          'ssl' => false,
          'ssl-verify' => false
        },
        'pcp' => {
          'task-environment' => 'testenv',
          'service-url' => 'http://foo.org',
          'token-file' => '/path/to/token',
          'cacert' => '/path/to/cacert'
        }
      } }
    end

    before(:each) do
      allow(Bolt::Util).to receive(:validate_file).and_return(true)
    end

    around :each do |example|
      in_project(config: project_config, inventory: inventory) do
        example.run
      end
    end

    it 'reads modulepath' do
      cli = Bolt::CLI.new(%w[command run uptime] + config_flags)
      cli.parse
      expect(cli.config.modulepath).to include(*modulepath)
    end

    it 'reads concurrency' do
      cli = Bolt::CLI.new(%w[command run uptime] + config_flags)
      cli.parse
      expect(cli.config.concurrency).to eq(14)
    end

    it 'reads compile-concurrency' do
      cli = Bolt::CLI.new(%w[command run uptime] + config_flags)
      cli.parse
      expect(cli.config.compile_concurrency).to eq(2)
    end

    it 'reads format' do
      cli = Bolt::CLI.new(%w[command run uptime] + config_flags)
      cli.parse
      expect(cli.config.format).to eq('json')
    end

    it 'reads log file' do
      cli = Bolt::CLI.new(%w[command run uptime] + config_flags)
      cli.parse
      normalized_path = File.expand_path(File.join(configdir, 'debug.log'))
      expect(cli.config.log).to include('console' => { level: 'warn' })
      expect(cli.config.log).to include("file:#{normalized_path}" => { level: 'debug', append: false })
    end

    it 'reads private-key for ssh' do
      cli = Bolt::CLI.new(%w[command run uptime] + config_flags)
      cli.parse
      cli.update_targets(cli.options)
      expect(cli.options[:targets].first.config['ssh']['private-key']).to match(%r{/bar/foo\z})
    end

    it 'reads host-key-check for ssh' do
      cli = Bolt::CLI.new(%w[command run uptime] + config_flags)
      cli.parse
      cli.update_targets(cli.options)
      expect(cli.options[:targets].first.config['ssh']['private-key']).to match(%r{/bar/foo\z})
      expect(cli.options[:targets].first.config['ssh']['host-key-check']).to eq(false)
    end

    it 'reads run-as for ssh' do
      cli = Bolt::CLI.new(%w[command run r --password bar] + config_flags)
      cli.parse
      cli.update_targets(cli.options)
      expect(cli.options[:targets].first.config['ssh']['run-as']).to eq('Fakey McFakerson')
    end

    it 'reads separate connect-timeout for ssh and winrm' do
      cli = Bolt::CLI.new(%w[command run uptime] + config_flags)
      cli.parse
      cli.update_targets(cli.options)
      expect(cli.options[:targets].first.config['ssh']['connect-timeout']).to eq(4)
      expect(cli.options[:targets].first.config['winrm']['connect-timeout']).to eq(7)
    end

    it 'reads ssl for winrm' do
      cli = Bolt::CLI.new(%w[command run uptime --targets foo])
      cli.parse
      cli.update_targets(cli.options)
      expect(cli.options[:targets].first.config['winrm']['ssl']).to eq(false)
    end

    it 'reads ssl-verify for winrm' do
      cli = Bolt::CLI.new(%w[command run uptime --targets foo])
      cli.parse
      cli.update_targets(cli.options)
      expect(cli.options[:targets].first.config['winrm']['ssl-verify']).to eq(false)
    end

    it 'reads extensions for winrm' do
      cli = Bolt::CLI.new(%w[command run uptime] + config_flags)
      cli.parse
      cli.update_targets(cli.options)
      expect(cli.options[:targets].first.config['winrm']['extensions']).to eq(['.py', '.bat'])
    end

    it 'reads task environment for pcp' do
      cli = Bolt::CLI.new(%w[command run uptime] + config_flags)
      cli.parse
      cli.update_targets(cli.options)
      expect(cli.options[:targets].first.config['pcp']['task-environment']).to eq('testenv')
    end

    it 'reads service url for pcp' do
      cli = Bolt::CLI.new(%w[command run uptime] + config_flags)
      cli.parse
      cli.update_targets(cli.options)
      expect(cli.options[:targets].first.config['pcp']['service-url']).to eql('http://foo.org')
    end

    it 'reads token file for pcp' do
      cli = Bolt::CLI.new(%w[command run uptime] + config_flags)
      cli.parse
      cli.update_targets(cli.options)
      expect(cli.options[:targets].first.config['pcp']['token-file']).to match(%r{/path/to/token\z})
    end

    it 'reads separate cacert file for pcp and winrm' do
      cli = Bolt::CLI.new(%w[command run uptime] + config_flags)
      cli.parse
      cli.update_targets(cli.options)
      expect(cli.options[:targets].first.config['pcp']['cacert']).to match(%r{/path/to/cacert\z})
      expect(cli.options[:targets].first.config['winrm']['cacert']).to match(%r{/path/to/winrm-cacert\z})
    end

    it 'CLI flags override config' do
      cli = Bolt::CLI.new(%w[command run uptime --concurrency 12] + config_flags)
      cli.parse
      expect(cli.config.concurrency).to eq(12)
    end

    it 'raises an error if a config file is specified and invalid' do
      cli = Bolt::CLI.new(%W[command run uptime --project #{fixtures_path('configs', 'invalid')} --targets foo])
      expect {
        cli.parse
      }.to raise_error(Bolt::FileError, /Could not parse/)
    end
  end

  describe 'inventoryfile' do
    let(:invalid_inventory) { fixtures_path('inventory', 'invalid.yaml') }

    it 'raises an error if an inventory file is specified and invalid' do
      cli = Bolt::CLI.new(
        %W[command run uptime --inventoryfile #{invalid_inventory} --targets foo]
      )
      expect {
        cli.update_targets(cli.parse)
      }.to raise_error(Bolt::Error, /Could not parse/)
    end

    it 'lists targets the action would run on' do
      cli = Bolt::CLI.new(%w[inventory show -t localhost])
      expect_any_instance_of(Bolt::Outputter::Human).to receive(:print_targets)
      cli.execute(cli.parse)
    end

    it 'lists targets with resolved configuration' do
      cli = Bolt::CLI.new(%w[inventory show -t localhost --detail])
      expect_any_instance_of(Bolt::Outputter::Human).to receive(:print_target_info)
      cli.execute(cli.parse)
    end

    it 'lists groups in the inventory file' do
      cli = Bolt::CLI.new(%w[group show])
      expect_any_instance_of(Bolt::Outputter::Human).to receive(:print_groups)
      cli.execute(cli.parse)
    end

    context 'with BOLT_INVENTORY set' do
      before(:each) { ENV['BOLT_INVENTORY'] = '---' }
      after(:each) { ENV.delete('BOLT_INVENTORY') }

      it 'errors when BOLT_INVENTORY is set' do
        cli = Bolt::CLI.new(%W[command run id --inventoryfile #{invalid_inventory} --targets foo])
        expect {
          cli.parse
        }.to raise_error(Bolt::Error, /BOLT_INVENTORY is set/)
      end
    end
  end

  context 'when warning about CLI flags being overridden by inventory' do
    it "does not warn when no inventory is detected" do
      in_project do
        cli = Bolt::CLI.new(%w[command run whoami -t foo --password bar])
        cli.parse
      end

      expect(@log_output.readlines)
        .not_to include(/CLI arguments \[\\"password\\"\] may be overridden by Inventory/)
    end

    context 'when BOLT_INVENTORY is set' do
      before(:each) { ENV['BOLT_INVENTORY'] = JSON.dump(version: 2) }
      after(:each) { ENV.delete('BOLT_INVENTORY') }

      it "warns when BOLT_INVENTORY data is detected and CLI option could be overridden" do
        cli = Bolt::CLI.new(%w[command run whoami -t foo --password bar])
        cli.parse
        expect(@log_output.readlines.join)
          .to match(/CLI arguments \["password"\] may be overridden by Inventory: BOLT_INVENTORY/)
      end
    end

    context 'when inventory file is set' do
      let(:inventoryfile) { fixtures_path('inventory', 'empty.yaml') }
      it "warns when BOLT_INVENTORY data is detected and CLI option could be overridden" do
        cli = Bolt::CLI.new(%W[command run whoami -t foo --password bar --inventoryfile #{inventoryfile}])
        cli.parse
        expect(@log_output.readlines.join)
          .to match(/CLI arguments \["password"\] may be overridden by Inventory:/)
      end
    end
  end
end
