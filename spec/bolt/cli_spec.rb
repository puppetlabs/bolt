# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/task'
require 'bolt/cli'
require 'bolt/util'
require 'concurrent/utility/processor_counter'
require 'r10k/action/puppetfile/install'
require 'yaml'

describe "Bolt::CLI" do
  include BoltSpec::Files
  include BoltSpec::Task
  let(:target) { Bolt::Target.new('foo') }

  before(:each) do
    outputter = Bolt::Outputter::Human.new(false, false, false, StringIO.new)

    allow_any_instance_of(Bolt::CLI).to receive(:outputter).and_return(outputter)
    allow_any_instance_of(Bolt::CLI).to receive(:warn)

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
    allow(Bolt::Util).to receive(:read_config_file).and_return(file_content)
  end

  context "without a config file" do
    let(:boltdir) { Bolt::Boltdir.new('.') }
    before(:each) do
      allow(Bolt::Boltdir).to receive(:find_boltdir).and_return(boltdir)
      allow_any_instance_of(Bolt::Boltdir).to receive(:resource_types)
      allow(Bolt::Util).to receive(:read_config_file).and_return({})
    end

    it "generates an error message if an unknown argument is given" do
      cli = Bolt::CLI.new(%w[command run --unknown])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /Unknown argument '--unknown'/)
    end

    it "generates an error message if an unknown subcommand is given" do
      cli = Bolt::CLI.new(%w[-n bolt1 bolt2 command run whoami])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /Expected subcommand 'bolt2' to be one of/)
    end

    it "generates an error message if an unknown action is given" do
      cli = Bolt::CLI.new(%w[-n bolt1 command oops whoami])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /Expected action 'oops' to be one of/)
    end

    it "generates an error message is no action is given and one is expected" do
      cli = Bolt::CLI.new(%w[-n bolt1 command])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /Expected an action/)
    end

    it "works without an action if no action is expected" do
      cli = Bolt::CLI.new(%w[-n bolt1 apply file.pp])
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
        }.to output(/Usage: bolt/).to_stdout
      end

      it "accepts --help" do
        cli = Bolt::CLI.new(%w[--help])
        expect {
          expect {
            cli.parse
          }.to raise_error(Bolt::CLIExit)
        }.to output(/Usage: bolt/).to_stdout
      end

      context 'listing actions with help' do
        it 'accepts command' do
          cli = Bolt::CLI.new(%w[help command])
          expect {
            expect {
              cli.parse
            }.to raise_error(Bolt::CLIExit)
          }.to output(/Available actions are:.*run/m).to_stdout
        end

        it 'accepts script' do
          cli = Bolt::CLI.new(%w[help script])
          expect {
            expect {
              cli.parse
            }.to raise_error(Bolt::CLIExit)
          }.to output(/Available actions are:.*run/m).to_stdout
        end

        it 'accepts task' do
          cli = Bolt::CLI.new(%w[help task])
          expect {
            expect {
              cli.parse
            }.to raise_error(Bolt::CLIExit)
          }.to output(/Available actions are:.*show.*run/m).to_stdout
        end

        it 'accepts plan' do
          cli = Bolt::CLI.new(%w[help plan])
          expect {
            expect {
              cli.parse
            }.to raise_error(Bolt::CLIExit)
          }.to output(/Available actions are:.*show.*run/m).to_stdout
        end

        it 'accepts file' do
          cli = Bolt::CLI.new(%w[help file])
          expect {
            expect {
              cli.parse
            }.to raise_error(Bolt::CLIExit)
          }.to output(/Available actions are:.*upload/m).to_stdout
        end

        it 'accepts puppetfile' do
          cli = Bolt::CLI.new(%w[help puppetfile])
          expect {
            expect {
              cli.parse
            }.to raise_error(Bolt::CLIExit)
          }.to output(/Available actions are:.*install.*show-modules/m).to_stdout
        end

        it 'accepts inventory' do
          cli = Bolt::CLI.new(%w[help inventory])
          expect {
            expect {
              cli.parse
            }.to raise_error(Bolt::CLIExit)
          }.to output(/Available actions are:.*show/m).to_stdout
        end

        it 'excludes invalid subcommand flags' do
          cli = Bolt::CLI.new(%w[help puppetfile])
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
          }.not_to output(/[parameters].*nodes/m).to_stdout
        end

        it 'accepts apply' do
          cli = Bolt::CLI.new(%w[help apply])
          expect {
            expect {
              cli.parse
            }.to raise_error(Bolt::CLIExit)
          }.to output(/Usage: bolt apply <manifest.pp>/m).to_stdout
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
        cli = Bolt::CLI.new(%w[command run uptime --nodes foo])
        expect(cli.parse).to include(targets: [target])
      end

      it "accepts multiple nodes" do
        cli = Bolt::CLI.new(%w[command run uptime --nodes foo,bar])
        expect(cli.parse).to include(targets: targets)
      end

      it "accepts multiple nodes across multiple declarations" do
        cli = Bolt::CLI.new(%w[command run uptime --nodes foo,bar --nodes bar,more,bars])
        extra_targets = [Bolt::Target.new('more'), Bolt::Target.new('bars')]
        expect(cli.parse).to include(targets: targets + extra_targets)
      end

      it "reads from stdin when --nodes is '-'" do
        nodes = <<~'NODES'
         foo
         bar
        NODES
        cli = Bolt::CLI.new(%w[command run uptime --nodes -])
        allow(STDIN).to receive(:read).and_return(nodes)
        result = cli.parse
        expect(result[:targets]).to eq(targets)
      end

      it "reads from a file when --nodes starts with @" do
        nodes = <<~'NODES'
          foo
          bar
        NODES
        with_tempfile_containing('nodes-args', nodes) do |file|
          cli = Bolt::CLI.new(%W[command run uptime --nodes @#{file.path}])
          result = cli.parse
          expect(result[:targets]).to eq(targets)
        end
      end

      it "strips leading and trailing whitespace" do
        nodes = "  foo\nbar  \nbaz\nqux  "
        with_tempfile_containing('nodes-args', nodes) do |file|
          cli = Bolt::CLI.new(%W[command run uptime --nodes @#{file.path}])
          result = cli.parse
          extra_targets = [Bolt::Target.new('baz'), Bolt::Target.new('qux')]
          expect(result[:targets]).to eq(targets + extra_targets)
        end
      end

      it "expands tilde to a user directory when --nodes starts with @" do
        expect(File).to receive(:read).with(File.join(Dir.home, 'nodes.txt')).and_return("foo\nbar\n")
        cli = Bolt::CLI.new(%w[command run uptime --nodes @~/nodes.txt])
        allow(cli).to receive(:puppetdb_client)
        result = cli.parse
        expect(result[:targets]).to eq(targets)
      end

      it "generates an error message if no nodes given" do
        cli = Bolt::CLI.new(%w[command run uptime --nodes])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Option '--nodes' needs a parameter/)
      end

      it "generates an error message if nodes is omitted" do
        cli = Bolt::CLI.new(%w[command run uptime])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Command requires a targeting option/)
      end
    end

    describe "targets" do
      let(:targets) { [target, Bolt::Target.new('bar')] }

      it "reads from a file when --nodes starts with @" do
        nodes = <<~'NODES'
          foo
          bar
        NODES
        with_tempfile_containing('nodes-args', nodes) do |file|
          cli = Bolt::CLI.new(%W[command run uptime --targets @#{file.path}])
          result = cli.parse
          expect(result[:targets]).to eq(targets)
        end
      end

      it "generates an error message if no targets are given" do
        cli = Bolt::CLI.new(%w[command run uptime --targets])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Option '--targets' needs a parameter/)
      end

      it "generates an error if nodes and targets are specified" do
        cli = Bolt::CLI.new(%w[command run uptime --nodes foo --targets bar])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Only one targeting option/)
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

        result = cli.parse
        expect(result[:targets]).to eq(targets)
      end

      it "fails if it can't retrieve targets from PuppetDB" do
        cli = Bolt::CLI.new(%w[command run id --query nodes{}])
        puppetdb = double('puppetdb')
        allow(puppetdb).to receive(:query_certnames).and_raise(Bolt::PuppetDBError, "failed to puppetdb the nodes")
        allow(cli).to receive(:puppetdb_client).and_return(puppetdb)

        expect { cli.parse }
          .to raise_error(Bolt::PuppetDBError, /failed to puppetdb the nodes/)
      end

      it "fails if both --nodes and --query are specified" do
        cli = Bolt::CLI.new(%w[command run id --query nodes{} --nodes foo,bar])

        expect { cli.parse }.to raise_error(Bolt::CLIError, /Only one/)
      end
    end

    describe "user" do
      it "accepts a user" do
        cli = Bolt::CLI.new(%w[command run uptime --user root --nodes foo])
        expect(cli.parse).to include(user: 'root')
      end

      it "generates an error message if no user value is given" do
        cli = Bolt::CLI.new(%w[command run uptime --nodes foo --user])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Option '--user' needs a parameter/)
      end
    end

    describe "password" do
      it "accepts a password" do
        cli = Bolt::CLI.new(%w[command run uptime --password opensesame --nodes foo])
        expect(cli.parse).to include(password: 'opensesame')
      end

      it "prompts the user for password if not specified" do
        allow(STDIN).to receive(:noecho).and_return('opensesame')
        allow(STDOUT).to receive(:print).with('Please enter your password: ')
        allow(STDOUT).to receive(:puts)
        cli = Bolt::CLI.new(%w[command run uptime --nodes foo --password])
        expect(cli.parse).to include(password: 'opensesame')
      end
    end

    describe "key" do
      it "accepts a private key" do
        cli = Bolt::CLI.new(%w[  command run uptime
                                 --private-key ~/.ssh/google_compute_engine
                                 --nodes foo])
        expect(cli.parse).to include('private-key': '~/.ssh/google_compute_engine')
        expect(cli.config.transports[:ssh]['private-key']).to eq('~/.ssh/google_compute_engine')
      end

      it "generates an error message if no key value is given" do
        cli = Bolt::CLI.new(%w[command run --nodes foo --private-key])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError,
                         /Option '--private-key' needs a parameter/)
      end
    end

    describe "concurrency" do
      it "accepts a concurrency limit" do
        cli = Bolt::CLI.new(%w[command run uptime --concurrency 10 --nodes foo])
        expect(cli.parse).to include(concurrency: 10)
      end

      it "defaults to 100" do
        cli = Bolt::CLI.new(%w[command run uptime --nodes foo])
        cli.parse
        expect(cli.config.concurrency).to eq(100)
      end

      it "generates an error message if no concurrency value is given" do
        cli = Bolt::CLI.new(%w[command run uptime --nodes foo --concurrency])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError,
                         /Option '--concurrency' needs a parameter/)
      end
    end

    describe "compile-concurrency" do
      it "accepts a concurrency limit" do
        cli = Bolt::CLI.new(%w[command run uptime --compile-concurrency 2 --nodes foo])
        expect(cli.parse).to include('compile-concurrency': 2)
      end

      it "defaults to unset" do
        cli = Bolt::CLI.new(%w[command run uptime --nodes foo])
        cli.parse
        # verifies Etc.nprocessors is the same as Concurrent.processor_count
        expect(cli.config.compile_concurrency).to eq(Concurrent.processor_count)
      end

      it "generates an error message if no concurrency value is given" do
        cli = Bolt::CLI.new(%w[command run uptime --nodes foo --compile-concurrency])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError,
                         /Option '--compile-concurrency' needs a parameter/)
      end
    end

    describe "console log level" do
      it "is not sensitive to ordering of debug and verbose" do
        expect(Bolt::Logger).to receive(:configure).with({ 'console' => { level: :debug } }, true)

        cli = Bolt::CLI.new(%w[command run uptime --nodes foo --debug --verbose])
        cli.parse
      end
    end

    describe "host-key-check" do
      it "accepts `--host-key-check`" do
        cli = Bolt::CLI.new(%w[command run uptime --host-key-check --nodes foo])
        cli.parse
        expect(cli.config.transports[:ssh]['host-key-check']).to eq(true)
      end

      it "accepts `--no-host-key-check`" do
        cli = Bolt::CLI.new(%w[command run uptime --no-host-key-check --nodes foo])
        cli.parse
        expect(cli.config.transports[:ssh]['host-key-check']).to eq(false)
      end

      it "defaults to nil" do
        cli = Bolt::CLI.new(%w[command run uptime --nodes foo])
        cli.parse
        expect(cli.config.transports[:ssh]['host-key-check']).to eq(nil)
      end
    end

    describe "connect-timeout" do
      it "accepts a specific timeout" do
        cli = Bolt::CLI.new(%w[command run uptime --connect-timeout 123 --nodes foo])
        expect(cli.parse).to include('connect-timeout': 123)
      end

      it "generates an error message if no timeout value is given" do
        cli = Bolt::CLI.new(%w[command run uptime --nodes foo --connect-timeout])
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
        cli = Bolt::CLI.new(%W[command run uptime --modulepath #{modulepath} --nodes foo])
        expect(cli.parse).to include(modulepath: [site, File.expand_path('modules')])
      end

      it "accepts shorthand -m" do
        site = File.expand_path('site')
        modulepath = [site, 'modules'].join(File::PATH_SEPARATOR)
        cli = Bolt::CLI.new(%W[command run uptime -m #{modulepath} --nodes foo])
        expect(cli.parse).to include(modulepath: [site, File.expand_path('modules')])
      end

      it "generates an error message if no value is given" do
        cli = Bolt::CLI.new(%w[command run uptime --nodes foo --modulepath])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError,
                         /Option '--modulepath' needs a parameter/)
      end
    end

    describe "sudo" do
      it "supports running as a user" do
        cli = Bolt::CLI.new(%w[command run --nodes foo whoami --run-as root])
        expect(cli.parse[:'run-as']).to eq('root')
      end
    end

    describe "sudo-password" do
      it "accepts a password" do
        cli = Bolt::CLI.new(%w[command run uptime --sudo-password opensez --run-as alibaba --nodes foo])
        expect(cli.parse).to include('sudo-password': 'opensez')
      end

      it "prompts the user for sudo-password if not specified" do
        allow(STDIN).to receive(:noecho).and_return('opensez')
        pw_prompt = 'Please enter your privilege escalation password: '
        allow(STDOUT).to receive(:print).with(pw_prompt)
        allow(STDOUT).to receive(:puts)
        cli = Bolt::CLI.new(%w[command run uptime --nodes foo --run-as alibaba --sudo-password])
        expect(cli.parse).to include('sudo-password': 'opensez')
      end
    end

    describe "transport" do
      it "defaults to 'ssh'" do
        cli = Bolt::CLI.new(%w[command run --nodes foo whoami])
        cli.parse
        expect(cli.config.transport).to eq('ssh')
      end

      it "accepts ssh" do
        cli = Bolt::CLI.new(%w[command run --transport ssh --nodes foo id])
        expect(cli.parse[:transport]).to eq('ssh')
      end

      it "accepts winrm" do
        cli = Bolt::CLI.new(%w[command run --transport winrm --nodes foo id])
        expect(cli.parse[:transport]).to eq('winrm')
      end

      it "accepts pcp" do
        cli = Bolt::CLI.new(%w[command run --transport pcp --nodes foo id])
        expect(cli.parse[:transport]).to eq('pcp')
      end

      it "rejects invalid transports" do
        cli = Bolt::CLI.new(%w[command run --transport holodeck --nodes foo id])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError,
                         /Invalid parameter specified for option '--transport': holodeck/)
      end
    end

    describe "command" do
      it "interprets whoami as the command" do
        cli = Bolt::CLI.new(%w[command run --nodes foo whoami])
        expect(cli.parse[:object]).to eq('whoami')
      end

      it "errors when a command is not specified" do
        cli = Bolt::CLI.new(%w[command run --nodes foo])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Must specify a command to run/)
      end

      it "errors when a command is empty string" do
        cli = Bolt::CLI.new(['command', 'run', '', '--nodes', 'foo'])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Must specify a command to run/)
      end
    end

    it "distinguishes subcommands" do
      cli = Bolt::CLI.new(%w[script run --nodes foo])
      expect(cli.parse).to include(subcommand: 'script')
    end

    describe "file" do
      describe "upload" do
        it "uploads a file" do
          cli = Bolt::CLI.new(%w[file upload ./src /path/dest --nodes foo])
          result = cli.parse
          expect(result[:object]).to eq('./src')
          expect(result[:leftovers].first).to eq('/path/dest')
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
        allow(STDIN).to receive(:read).and_return(json_args)
        result = cli.parse
        expect(result[:task_options]).to eq('kj' => '2hv',
                                            'iuhg' => 'iube',
                                            '2whf' => 'lcv')
      end
    end

    describe 'task' do
      it "errors without a task" do
        cli = Bolt::CLI.new(%w[task run -n example.com --modulepath .])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Must specify/)
      end

      it "errors if task is a parameter" do
        cli = Bolt::CLI.new(%w[task run -n example.com --modulepath . p1=v1])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Invalid task/)
      end

      it "fails show with --noop" do
        expected = "Option '--noop' may only be specified when running a task or applying manifest code"
        expect {
          cli = Bolt::CLI.new(%w[task show foo --nodes bar --noop])
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
        cli = Bolt::CLI.new(%w[plan run foo --query nodes{}])
        allow(cli).to receive(:query_puppetdb_nodes).once.and_return(%w[foo bar])
        targets = [Bolt::Target.new('foo'), Bolt::Target.new('bar')]
        result = cli.parse
        cli.validate(result)
        cli.execute(result)
        expect(result[:targets]).to eq(targets)
        expect(result[:target_args]).to eq(%w[foo bar])
      end

      it "fails when --nodes AND --query provided" do
        expect {
          cli = Bolt::CLI.new(%w[plan run foo --query nodes{} --nodes bar])
          cli.parse
        }.to raise_error(Bolt::CLIError, /Only one targeting option/)
      end

      it "fails with --noop" do
        expected = "Option '--noop' may only be specified when running a task or applying manifest code"
        expect {
          cli = Bolt::CLI.new(%w[plan run foo --nodes bar --noop])
          cli.parse
        }.to raise_error(Bolt::CLIError, expected)
      end
    end

    describe 'apply' do
      it "errors without an object or inline code" do
        expect {
          cli = Bolt::CLI.new(%w[apply --nodes bar])
          cli.parse
        }.to raise_error(Bolt::CLIError, 'a manifest file or --execute is required')
      end

      it "errors with both an object and inline code" do
        expect {
          cli = Bolt::CLI.new(%w[apply foo.pp --execute hello --nodes bar])
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
        cli = Bolt::CLI.new(%w[command run foo --nodes bar])
        cli.parse
        expect(cli.bundled_content).to eq(empty_content)
      end

      it "does not calculate bundled content for a script" do
        cli = Bolt::CLI.new(%w[script run foo --nodes bar])
        cli.parse
        expect(cli.bundled_content).to eq(empty_content)
      end

      it "does not calculate bundled content for a file" do
        cli = Bolt::CLI.new(%w[file upload /tmp /var foo --nodes bar])
        cli.parse
        expect(cli.bundled_content).to eq(empty_content)
      end

      it "calculates bundled content for a task" do
        cli = Bolt::CLI.new(%w[task run foo --nodes bar])
        cli.parse
        expect(cli.bundled_content['Task']).not_to be_empty
      end

      it "calculates bundled content for a plan" do
        cli = Bolt::CLI.new(%w[plan run foo --nodes bar])
        cli.parse
        expect(cli.bundled_content['Plan']).not_to be_empty
        expect(cli.bundled_content['Task']).not_to be_empty
      end
    end

    describe "execute" do
      let(:executor) { double('executor', noop: false, subscribe: nil, shutdown: nil) }
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
        allow(Bolt::Executor).to receive(:new).and_return(executor)
        allow(executor).to receive(:log_plan) { |_plan_name, &block| block.call }

        outputter = Bolt::Outputter::JSON.new(false, false, false, output)

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
          cli.config.modulepath = [File.join(__FILE__, '../../fixtures/modules')]
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

        it "lists modulepath" do
          options = {
            subcommand: 'task',
            action: 'show'
          }
          cli.execute(options)
          modulepath = JSON.parse(output.string)['modulepath']
          expect(modulepath).to include(File.join(__FILE__, '../../fixtures/modules').to_s)
        end

        it "does not list a private task" do
          options = {
            subcommand: 'task',
            action: 'show'
          }
          cli.execute(options)
          tasks = JSON.parse(output.string)['tasks']
          expect(tasks).not_to include(['sample::private', 'Do not list this task'])
        end

        it "shows invidual private task" do
          task_name = 'sample::private'
          options = {
            subcommand: 'task',
            action: 'show',
            object: task_name
          }
          cli.execute(options)
          json = JSON.parse(output.string)
          json.delete("files")
          expect(json).to eq(
            "name" => "sample::private",
            "metadata" => { "name" => "Private Task",
                            "description" => "Do not list this task",
                            "private" => true },
            "module_dir" => File.absolute_path(File.join(__dir__, "..", "fixtures", "modules", "sample"))
          )
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
            "module_dir" => File.absolute_path(File.join(__dir__, "..", "fixtures", "modules", "sample")),
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
          cli.config.modulepath = [File.join(__FILE__, '../../fixtures/invalid_mods')]
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
          cli.config.modulepath = [File.join(__FILE__, '../../fixtures/modules')]
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
            'Could not find a task named "abcdefg". For a list of available tasks, run "bolt task show"'
          )
        end
      end

      context "when showing available plans", :reset_puppet_settings do
        before :each do
          cli.config.modulepath = [File.join(__FILE__, '../../fixtures/modules')]
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
          expect(modulepath).to include(File.join(__FILE__, '../../fixtures/modules').to_s)
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
            "module_dir" => File.absolute_path(File.join(__dir__, "..", "fixtures", "modules", "sample")),
            "parameters" => {
              "param_mandatory" => {
                "type" => "String"
              },
              "param_optional" => {
                "type" => "Optional[String]"
              },
              "param_with_default_value" => {
                "type" => "String",
                "default_value" => nil
              }
            }
          )
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
            "module_dir" => File.absolute_path(File.join(__dir__, "..", "fixtures", "modules", "sample")),
            "parameters" => {
              "nodes" => {
                "type" => "TargetSpec"
              },
              "param_optional" => {
                "type" => "Optional[String]",
                "default_value" => nil
              },
              "param_with_default_value" => {
                "type" => "String",
                "default_value" => nil
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
          cli.config.modulepath = [File.join(__FILE__, '../../fixtures/invalid_mods')]
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
                                  ["aggregate::nodes"],
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
          cli.config.modulepath = [File.join(__FILE__, '../../fixtures/modules')]
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
            'Could not find a plan named "abcdefg". For a list of available plans, run "bolt plan show"'
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
          cli.config.modulepath = [File.join(__FILE__, '../../fixtures/modules')]
        end

        it "runs a task given a name" do
          expect(executor)
            .to receive(:run_task)
            .with(targets, task_t, task_params, kind_of(Hash))
            .and_return(Bolt::ResultSet.new([]))
          expect(cli.execute(options)).to eq(0)
          expect(JSON.parse(output.string)).to be
        end

        it "returns 2 if any node fails" do
          expect(executor)
            .to receive(:run_task)
            .with(targets, task_t, task_params, kind_of(Hash))
            .and_return(fail_set)

          expect(cli.execute(options)).to eq(2)
        end

        it "errors for non-existent modules" do
          task_name.replace 'dne::task1'

          expect { cli.execute(options) }.to raise_error(
            Bolt::Error, /Could not find a task named "dne::task1"/
          )
          expect(JSON.parse(output.string)).to be
        end

        it "errors for non-existent tasks" do
          task_name.replace 'sample::dne'

          expect { cli.execute(options) }.to raise_error(
            Bolt::Error, /Could not find a task named "sample::dne"/
          )
          expect(JSON.parse(output.string)).to be
        end

        it "raises errors from the executor" do
          task_params.clear

          expect(executor)
            .to receive(:run_task)
            .with(targets, task_t, {}, kind_of(Hash))
            .and_raise("Could not connect to target")

          expect { cli.execute(options) }.to raise_error(/Could not connect to target/)
        end

        it "runs an init task given a module name" do
          task_name.replace 'sample'
          task_path.replace 'modules/sample/tasks/init.sh$'

          expect(executor)
            .to receive(:run_task)
            .with(targets, task_t, task_params, kind_of(Hash))
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
              .with(targets, task_t, task_params, kind_of(Hash))
              .and_return(Bolt::ResultSet.new([]))

            cli.execute(options)
            expect(JSON.parse(output.string)).to be
          end

          it "runs a powershell task passing input on stdin" do
            task_name.replace 'sample::winstdin'
            task_path.replace 'modules/sample/tasks/winstdin.ps1$'

            expect(executor)
              .to receive(:run_task)
              .with(targets, task_t, task_params, kind_of(Hash))
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
              /Task sample::params:\n(?x:
               )\s*has no parameter named 'foo'\n(?x:
               )\s*has no parameter named 'bar'/
            )
            expect(JSON.parse(output.string)).to be
          end

          it "errors when required parameters are not specified" do
            task_params['mandatory_string'] = 'str'

            expect { cli.execute(options) }.to raise_error(
              Bolt::PAL::PALError,
              /Task sample::params:\n(?x:
               )\s*expects a value for parameter 'mandatory_integer'\n(?x:
               )\s*expects a value for parameter 'mandatory_boolean'/
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
              /Task sample::params:\n(?x:
               )\s*parameter 'mandatory_boolean' expects a Boolean value, got String\n(?x:
               )\s*parameter 'optional_string' expects a value of type Undef or String,(?x:
                                             ) got Integer/
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
              /Task sample::params:\n(?x:
               )\s*parameter 'mandatory_string' expects a String\[1, 10\] value, got String\n(?x:
               )\s*parameter 'optional_integer' expects a value of type Undef or Integer\[-5, 5\],(?x:
                                              ) got Integer\[10, 10\]/
            )
            expect(JSON.parse(output.string)).to be
          end

          it "runs the task when the specified parameters are successfully validated" do
            expect(executor)
              .to receive(:run_task)
              .with(targets, task_t, task_params, kind_of(Hash))
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
                'foo' => nil,
                'bar' => nil
              }
            }

            context "when some targets don't use the PCP transport" do
              it "errors as usual if the task is not available locally" do
                task_name.replace 'unknown::task'

                expect { cli.execute(options) }.to raise_error(
                  Bolt::Error, /Could not find a task named "unknown::task"/
                )
                expect(JSON.parse(output.string)).to be
              end

              it "errors as usual if invalid (according to the local task definition) parameters are specified" do
                expect { cli.execute(options) }.to raise_error(
                  Bolt::PAL::PALError,
                  /Task sample::params:\n(?x:
                   )\s*has no parameter named 'foo'\n(?x:
                   )\s*has no parameter named 'bar'/
                )
                expect(JSON.parse(output.string)).to be
              end
            end

            context "when all targets use the PCP transport" do
              let(:target) { Bolt::Target.new('pcp://foo') }
              let(:task_t) { task_type(task_name, /\A\z/, nil) }

              it "runs the task even when it is not installed locally" do
                task_name.replace 'unknown::task'

                expect(executor)
                  .to receive(:run_task)
                  .with(targets, task_t, task_params, kind_of(Hash))
                  .and_return(Bolt::ResultSet.new([]))

                cli.execute(options)
                expect(JSON.parse(output.string)).to be
              end

              it "runs the task even when invalid (according to the local task definition) parameters are specified" do
                expect(executor)
                  .to receive(:run_task)
                  .with(targets, task_t, task_params, kind_of(Hash))
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
            target_args: [],
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
          cli.config.modulepath = [File.join(__FILE__, '../../fixtures/modules')]
        end

        it "uses the nodes passed using the --nodes option(s) as the 'nodes' plan parameter" do
          plan_params.clear
          options[:target_args] = targets.map(&:host)

          expect(executor)
            .to receive(:run_task)
            .with(targets, task_t, { 'message' => 'hi there' }, kind_of(Hash))
            .and_return(Bolt::ResultSet.new([Bolt::Result.for_task(target, 'yes', '', 0, 'some_task')]))

          expect(executor).to receive(:start_plan)
          expect(executor).to receive(:log_plan)
          expect(executor).to receive(:finish_plan)

          cli.execute(options)
          expect(JSON.parse(output.string)).to eq(
            [{ 'node' => 'foo',
               'target' => 'foo',
               'status' => 'success',
               'action' => 'task',
               'object' => 'some_task',
               'result' => { '_output' => 'yes' } }]
          )
        end

        it "errors when the --nodes option(s) and the 'nodes' plan parameter are both specified" do
          options[:target_args] = targets.map(&:host)

          expect { cli.execute(options) }.to raise_error(
            /A plan's 'nodes' parameter may be specified using the --nodes option, (?x:
             )but in that case it must not be specified as a separate nodes=<value> (?x:
             )parameter nor included in the JSON data passed in the --params option/
          )
        end

        it "formats results of a passing task" do
          expect(executor)
            .to receive(:run_task)
            .with(targets, task_t, { 'message' => 'hi there' }, kind_of(Hash))
            .and_return(Bolt::ResultSet.new([Bolt::Result.for_task(target, 'yes', '', 0, 'some_task')]))

          expect(executor).to receive(:start_plan)
          expect(executor).to receive(:log_plan)
          expect(executor).to receive(:finish_plan)

          cli.execute(options)
          expect(JSON.parse(output.string)).to eq(
            [{ 'node' => 'foo',
               'target' => 'foo',
               'status' => 'success',
               'action' => 'task',
               'object' => 'some_task',
               'result' => { '_output' => 'yes' } }]
          )
        end

        it "raises errors from the executor" do
          expect(executor)
            .to receive(:run_task)
            .with(targets, task_t, { 'message' => 'hi there' }, kind_of(Hash))
            .and_raise("Could not connect to target")

          expect(executor).to receive(:start_plan)
          expect(executor).to receive(:log_plan)
          expect(executor).to receive(:finish_plan)

          expect(cli.execute(options)).to eq(1)
          expect(JSON.parse(output.string)['msg']).to match(/Could not connect to target/)
        end

        it "formats results of a failing task" do
          expect(executor)
            .to receive(:run_task)
            .with(targets, task_t, { 'message' => 'hi there' }, kind_of(Hash))
            .and_return(Bolt::ResultSet.new([Bolt::Result.for_task(target, 'no', '', 1, 'some_task')]))

          expect(executor).to receive(:start_plan)
          expect(executor).to receive(:log_plan)
          expect(executor).to receive(:finish_plan)

          cli.execute(options)
          expect(JSON.parse(output.string)).to eq(
            [
              {
                'node' => 'foo',
                'target' => 'foo',
                'status' => 'failure',
                'action' => 'task',
                'object' => 'some_task',
                'result' => {
                  "_output" => "no",
                  "_error" => {
                    "msg" => "The task failed with exit code 1",
                    "kind" => "puppetlabs.tasks/task-error",
                    "details" => { "exit_code" => 1 },
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
          expect(JSON.parse(output.string)['msg']).to match(/Could not find a plan named "sample::dne"/)
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
      let(:executor) { double('executor', noop: true, subscribe: nil, shutdown: nil) }
      let(:cli) { Bolt::CLI.new({}) }
      let(:targets) { [target] }
      let(:output) { StringIO.new }
      let(:bundled_content) { ['test'] }

      before :each do
        allow(cli).to receive(:bundled_content).and_return(bundled_content)
        expect(Bolt::Executor).to receive(:new).with(Bolt::Config.default.concurrency,
                                                     anything,
                                                     true).and_return(executor)

        plugins = Bolt::Plugin.new(nil, nil, nil)
        allow(cli).to receive(:plugins).and_return(plugins)

        outputter = Bolt::Outputter::JSON.new(false, false, false, output)
        allow(cli).to receive(:outputter).and_return(outputter)
        allow(executor).to receive(:report_bundled_content)
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
          cli.config.modulepath = [File.join(__FILE__, '../../fixtures/modules')]
        end

        it "runs a task that supports noop" do
          expect(executor)
            .to receive(:run_task)
            .with(targets, task_t, task_params.merge('_noop' => true), kind_of(Hash))
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

    describe "installing a Puppetfile" do
      let(:options) {
        {
          subcommand: 'puppetfile',
          action: 'run'
        }
      }
      let(:output) { StringIO.new }
      let(:puppetfile) { Pathname.new('path/to/puppetfile') }
      let(:modulepath) { [Pathname.new('path/to/modules')] }
      let(:action_stub) { double('r10k_action_puppetfile_install') }

      let(:cli) { Bolt::CLI.new({}) }

      before :each do
        allow(cli).to receive(:outputter).and_return(Bolt::Outputter::JSON.new(false, false, false, output))
        allow(puppetfile).to receive(:exist?).and_return(true)
        allow_any_instance_of(Bolt::PAL).to receive(:generate_types)
        allow(R10K::Action::Puppetfile::Install).to receive(:new).and_return(action_stub)
      end

      it 'fails if the Puppetfile does not exist' do
        allow(puppetfile).to receive(:exist?).and_return(false)

        expect do
          cli.install_puppetfile({}, puppetfile, modulepath)
        end.to raise_error(Bolt::FileError, /Could not find a Puppetfile/)
      end

      it 'installs to the first directory of the modulepath' do
        expect(R10K::Action::Puppetfile::Install).to receive(:new)
          .with({ root: puppetfile.dirname.to_s, puppetfile: puppetfile.to_s, moduledir: modulepath.first.to_s }, nil)

        allow(action_stub).to receive(:call).and_return(true)

        cli.install_puppetfile({}, puppetfile, modulepath)
      end

      it 'returns 0 and prints a result if successful' do
        allow(action_stub).to receive(:call).and_return(true)

        expect(cli.install_puppetfile({}, puppetfile, modulepath)).to eq(0)

        result = JSON.parse(output.string)
        expect(result['success']).to eq(true)
        expect(result['puppetfile']).to eq(puppetfile.to_s)
        expect(result['moduledir']).to eq(modulepath.first.to_s)
      end

      it 'returns 1 and prints a result if unsuccessful' do
        allow(action_stub).to receive(:call).and_return(false)

        expect(cli.install_puppetfile({}, puppetfile, modulepath)).to eq(1)

        result = JSON.parse(output.string)
        expect(result['success']).to eq(false)
        expect(result['puppetfile']).to eq(puppetfile.to_s)
        expect(result['moduledir']).to eq(modulepath.first.to_s)
      end

      it 'propagates any r10k errors' do
        allow(action_stub).to receive(:call).and_raise(R10K::Error.new('everything is terrible'))

        expect do
          cli.install_puppetfile({}, puppetfile, modulepath)
        end.to raise_error(Bolt::PuppetfileError, /everything is terrible/)

        expect(output.string).to be_empty
      end
    end

    describe "applying Puppet code" do
      let(:options) {
        {
          subcommand: 'apply'
        }
      }
      let(:output) { StringIO.new }
      let(:cli) { Bolt::CLI.new([]) }

      before :each do
        allow(cli).to receive(:outputter).and_return(Bolt::Outputter::JSON.new(false, false, false, output))
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

  describe 'configfile' do
    let(:configdir) { File.join(__dir__, '..', 'fixtures', 'configs') }
    let(:modulepath) { [File.expand_path('/foo/bar'), File.expand_path('/baz/qux')] }
    let(:complete_config) do
      { 'modulepath' => modulepath.join(File::PATH_SEPARATOR),
        'inventoryfile' => File.join(__dir__, '..', 'fixtures', 'inventory', 'empty.yml'),
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
        },
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
        } }
    end

    it 'reads modulepath' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --nodes foo --no-host-key-check])
        cli.parse
        expect(cli.config.modulepath).to eq(modulepath)
      end
    end

    it 'reads concurrency' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --nodes foo --no-host-key-check])
        cli.parse
        expect(cli.config.concurrency).to eq(14)
      end
    end

    it 'reads compile-concurrency' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --nodes foo --no-host-key-check])
        cli.parse
        expect(cli.config.compile_concurrency).to eq(2)
      end
    end

    it 'reads format' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --nodes foo --no-host-key-check])
        cli.parse
        expect(cli.config.format).to eq('json')
      end
    end

    it 'reads log file' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --nodes foo --no-host-key-check])
        cli.parse
        normalized_path = File.expand_path(File.join(configdir, 'debug.log'))
        expect(cli.config.log).to eq(
          'console' => { level: 'warn' },
          "file:#{normalized_path}" => { level: 'debug', append: false }
        )
      end
    end

    it 'reads private-key for ssh' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --nodes foo --no-host-key-check])
        cli.parse
        expect(cli.config.transports[:ssh]['private-key']).to eq('/bar/foo')
      end
    end

    it 'reads host-key-check for ssh' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --nodes foo])
        cli.parse
        expect(cli.config.transports[:ssh]['host-key-check']).to eq(false)
      end
    end

    it 'reads run-as for ssh' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run r --configfile #{conf.path} --nodes foo --password bar --no-host-key-check])
        cli.parse
        expect(cli.config.transports[:ssh]['run-as']).to eq('Fakey McFakerson')
      end
    end

    it 'reads separate connect-timeout for ssh and winrm' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --nodes foo --no-host-key-check --no-ssl])
        cli.parse
        expect(cli.config.transports[:ssh]['connect-timeout']).to eq(4)
        expect(cli.config.transports[:winrm]['connect-timeout']).to eq(7)
      end
    end

    it 'reads ssl for winrm' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --nodes foo])
        cli.parse
        expect(cli.config.transports[:winrm]['ssl']).to eq(false)
      end
    end

    it 'reads ssl-verify for winrm' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --nodes foo])
        cli.parse
        expect(cli.config.transports[:winrm]['ssl-verify']).to eq(false)
      end
    end

    it 'reads extensions for winrm' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --nodes foo --no-ssl])
        cli.parse
        expect(cli.config.transports[:winrm]['extensions']).to eq(['.py', '.bat'])
      end
    end

    it 'reads task environment for pcp' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --nodes foo])
        cli.parse
        expect(cli.config.transports[:pcp]['task-environment']).to eq('testenv')
      end
    end

    it 'reads service url for pcp' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --nodes foo])
        cli.parse
        expect(cli.config.transports[:pcp]['service-url']).to eql('http://foo.org')
      end
    end

    it 'reads token file for pcp' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --nodes foo])
        cli.parse
        expect(cli.config.transports[:pcp]['token-file']).to eql('/path/to/token')
      end
    end

    it 'reads separate cacert file for pcp and winrm' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --nodes foo --no-host-key-check --no-ssl])
        cli.parse
        expect(cli.config.transports[:pcp]['cacert']).to eql('/path/to/cacert')
        expect(cli.config.transports[:winrm]['cacert']).to eql('/path/to/winrm-cacert')
      end
    end

    it 'CLI flags override config' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --nodes foo --concurrency 12])
        cli.parse
        expect(cli.config.concurrency).to eq(12)
      end
    end

    it 'raises an error if a config file is specified and invalid' do
      cli = Bolt::CLI.new(%W[command run uptime --configfile #{File.join(configdir, 'invalid.yml')} --nodes foo])
      expect {
        cli.parse
      }.to raise_error(Bolt::FileError, /Could not parse/)
    end
  end

  describe 'inventoryfile' do
    let(:inventorydir) { File.join(__dir__, '..', 'fixtures', 'configs') }

    it 'raises an error if an inventory file is specified and invalid' do
      cli = Bolt::CLI.new(%W[command run uptime --inventoryfile #{File.join(inventorydir, 'invalid.yml')} --nodes foo])
      expect {
        cli.parse
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
        cli = Bolt::CLI.new(%W[command run id --inventoryfile #{File.join(inventorydir, 'invalid.yml')} --nodes foo])
        expect {
          cli.parse
        }.to raise_error(Bolt::Error, /BOLT_INVENTORY is set/)
      end
    end
  end
end
