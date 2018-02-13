require 'spec_helper'
require 'signal_helper'
require 'bolt_spec/files'
require 'bolt/cli'

describe "Bolt::CLI" do
  include BoltSpec::Files
  let(:target) { Bolt::Target.new('foo') }

  before(:each) do
    outputter = Bolt::Outputter::Human.new(StringIO.new)

    allow_any_instance_of(Bolt::CLI).to receive(:outputter).and_return(outputter)
    allow_any_instance_of(Bolt::CLI).to receive(:warn)

    # This will turn on logging to the console by default... not ideal for tests
    allow(Bolt::PAL).to receive(:configure_logging)
  end

  def stub_file(path)
    stat = double('stat', readable?: true, file?: true)

    allow(cli).to receive(:file_stat).with(path).and_return(stat)
  end

  def stub_non_existent_file(path)
    allow(cli).to receive(:file_stat).with(path).and_raise(
      Errno::ENOENT, "No such file or directory @ rb_file_s_stat - #{path}"
    )
  end

  def stub_unreadable_file(path)
    stat = double('stat', readable?: false, file?: true)

    allow(cli).to receive(:file_stat).with(path).and_return(stat)
  end

  def stub_directory(path)
    stat = double('stat', readable?: true, file?: false)

    allow(cli).to receive(:file_stat).with(path).and_return(stat)
  end

  def stub_config(config, file_content = nil)
    file_content ||= {}
    allow(Bolt::Util).to receive(:read_config_file).and_return(file_content)
    allow(Bolt::Config).to receive(:new).and_return(config)
  end

  context "without a config file" do
    let(:config) { Bolt::Config.new }
    before(:each) { stub_config(config) }

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
        cli = Bolt::CLI.new(%w[command run --nodes foo])
        expect(cli.parse).to include(targets: [target])
      end

      it "accepts multiple nodes" do
        cli = Bolt::CLI.new(%w[command run --nodes foo,bar])
        expect(cli.parse).to include(targets: targets)
      end

      it "accepts multiple nodes across multiple declarations" do
        cli = Bolt::CLI.new(%w[command run --nodes foo,bar --nodes bar,more,bars])
        extra_targets = [Bolt::Target.new('more'), Bolt::Target.new('bars')]
        expect(cli.parse).to include(targets: targets + extra_targets)
      end

      it "reads from stdin when --nodes is '-'" do
        nodes = <<-'NODES'
foo
bar
        NODES
        cli = Bolt::CLI.new(%w[command run --nodes -])
        allow(STDIN).to receive(:read).and_return(nodes)
        result = cli.parse
        expect(result[:targets]).to eq(targets)
      end

      it "reads from a file when --nodes starts with @" do
        nodes = <<-'NODES'
foo
bar
        NODES
        with_tempfile_containing('nodes-args', nodes) do |file|
          cli = Bolt::CLI.new(%W[command run --nodes @#{file.path}])
          result = cli.parse
          expect(result[:targets]).to eq(targets)
        end
      end

      it "strips leading and trailing whitespace" do
        nodes = "  foo\nbar  \nbaz\nqux  "
        with_tempfile_containing('nodes-args', nodes) do |file|
          cli = Bolt::CLI.new(%W[command run --nodes @#{file.path}])
          result = cli.parse
          extra_targets = [Bolt::Target.new('baz'), Bolt::Target.new('qux')]
          expect(result[:targets]).to eq(targets + extra_targets)
        end
      end

      it "generates an error message if no nodes given" do
        cli = Bolt::CLI.new(%w[command run --nodes])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Option '--nodes' needs a parameter/)
      end

      it "generates an error message if nodes is omitted" do
        cli = Bolt::CLI.new(%w[command run])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Option '--nodes' must be specified/)
      end

      it 'does not list nodes in plan --help' do
        cli = Bolt::CLI.new(%w[plan --help])
        expect {
          expect {
            cli.parse
          }.to raise_error(Bolt::CLIExit)
        }.not_to output(/--nodes/).to_stdout
      end

      it 'does not list nodes in help plan' do
        cli = Bolt::CLI.new(%w[help plan])
        expect {
          expect {
            cli.parse
          }.to raise_error(Bolt::CLIExit)
        }.not_to output(/--nodes/).to_stdout
      end

      it 'generates an error if --nodes is passed to plan' do
        cli = Bolt::CLI.new(%w[plan run foo --nodes foobar.com])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Unknown argument '--nodes'/)
      end
    end

    describe "user" do
      it "accepts a user" do
        cli = Bolt::CLI.new(%w[command run --user root --nodes foo])
        expect(cli.parse).to include(user: 'root')
      end

      it "generates an error message if no user value is given" do
        cli = Bolt::CLI.new(%w[command run --nodes foo --user])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError, /Option '--user' needs a parameter/)
      end
    end

    describe "password" do
      it "accepts a password" do
        cli = Bolt::CLI.new(%w[command run --password opensesame --nodes foo])
        expect(cli.parse).to include(password: 'opensesame')
      end

      it "prompts the user for password if not specified" do
        allow(STDIN).to receive(:noecho).and_return('opensesame')
        allow(STDOUT).to receive(:print).with('Please enter your password: ')
        allow(STDOUT).to receive(:puts)
        cli = Bolt::CLI.new(%w[command run --nodes foo --password])
        expect(cli.parse).to include(password: 'opensesame')
      end
    end

    describe "private-key" do
      it "accepts a private key" do
        cli = Bolt::CLI.new(%w[  command run
                                 --private-key ~/.ssh/google_compute_engine
                                 --nodes foo])
        expect(cli.parse).to include(key: '~/.ssh/google_compute_engine')
        expect(cli.config[:transports][:ssh][:key]).to eq('~/.ssh/google_compute_engine')
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
        cli = Bolt::CLI.new(%w[command run --concurrency 10 --nodes foo])
        expect(cli.parse).to include(concurrency: 10)
      end

      it "defaults to 100" do
        cli = Bolt::CLI.new(%w[command run --nodes foo])
        cli.parse
        expect(cli.config[:concurrency]).to eq(100)
      end

      it "generates an error message if no concurrency value is given" do
        cli = Bolt::CLI.new(%w[command run --nodes foo --concurrency])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError,
                         /Option '--concurrency' needs a parameter/)
      end
    end

    describe "log level" do
      let(:root_logger) { Logging.logger[:root] }
      after(:each) { root_logger.level = :notice }
      it "is not sensitive to ordering of debug and verbose" do
        cli = Bolt::CLI.new(%w[command run --nodes foo --debug --verbose])
        cli.parse
        expect(root_logger.level).to eq(Logging.level_num(:debug))
      end
    end

    describe "host_key_check" do
      it "accepts `--host-key-check`" do
        cli = Bolt::CLI.new(%w[command run --host-key-check --nodes foo])
        cli.parse
        expect(cli.config[:transports][:ssh][:host_key_check]).to eq(true)
      end

      it "accepts `--no-host-key-check`" do
        cli = Bolt::CLI.new(%w[command run --no-host-key-check --nodes foo])
        cli.parse
        expect(cli.config[:transports][:ssh][:host_key_check]).to eq(false)
      end

      it "defaults to true" do
        cli = Bolt::CLI.new(%w[command run --nodes foo])
        cli.parse
        expect(cli.config[:transports][:ssh][:host_key_check]).to eq(true)
      end
    end

    describe "connect_timeout" do
      it "accepts a specific timeout" do
        cli = Bolt::CLI.new(%w[command run --connect-timeout 123 --nodes foo])
        expect(cli.parse).to include(connect_timeout: 123)
      end

      it "generates an error message if no timeout value is given" do
        cli = Bolt::CLI.new(%w[command run --nodes foo --connect-timeout])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError,
                         /Option '--connect-timeout' needs a parameter/)
      end
    end

    describe "modulepath" do
      it "accepts a modulepath directory" do
        cli = Bolt::CLI.new(%w[command run --modulepath ./modules --nodes foo])
        expect(cli.parse).to include(modulepath: ['./modules'])
      end

      it "generates an error message if no value is given" do
        cli = Bolt::CLI.new(%w[command run --nodes foo --modulepath])
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIError,
                         /Option '--modulepath' needs a parameter/)
      end
    end

    describe "sudo" do
      it "supports running as a user" do
        cli = Bolt::CLI.new(%w[command run --nodes foo whoami --run-as root])
        expect(cli.parse[:run_as]).to eq('root')
      end
    end

    describe "sudo-password" do
      it "accepts a password" do
        cli = Bolt::CLI.new(%w[command run --sudo-password opensez --run-as alibaba --nodes foo])
        expect(cli.parse).to include(sudo_password: 'opensez')
      end

      it "prompts the user for sudo-password if not specified" do
        allow(STDIN).to receive(:noecho).and_return('opensez')
        pw_prompt = 'Please enter your privilege escalation password: '
        allow(STDOUT).to receive(:print).with(pw_prompt)
        allow(STDOUT).to receive(:puts)
        cli = Bolt::CLI.new(%w[command run --nodes foo --run-as alibaba --sudo-password])
        expect(cli.parse).to include(sudo_password: 'opensez')
      end
    end

    describe "transport" do
      it "defaults to 'ssh'" do
        cli = Bolt::CLI.new(%w[command run --nodes foo whoami])
        cli.parse
        expect(cli.config[:transport]).to eq('ssh')
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
        }.to raise_error(OptionParser::InvalidArgument,
                         /invalid argument: --transport holodeck/)
      end
    end

    describe "command" do
      it "interprets whoami as the command" do
        cli = Bolt::CLI.new(%w[command run --nodes foo whoami])
        expect(cli.parse[:object]).to eq('whoami')
      end
    end

    it "distinguishes subcommands" do
      cli = Bolt::CLI.new(%w[script run --nodes foo])
      expect(cli.parse).to include(mode: 'script')
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
        expect(result[:task_options]).to eq('kj'   => '2hv',
                                            'iuhg' => 'iube',
                                            '2whf' => 'lcv')
      end

      it "reads params in json with the params flag" do
        json_args = '{"kj":"2hv","iuhg":"iube","2whf":"lcv"}'
        cli = Bolt::CLI.new(['plan', 'run', 'my::plan', '--params', json_args,
                             '--modulepath', '.'])
        result = cli.parse
        expect(result[:task_options]).to eq('kj'   => '2hv',
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
          expect(result[:task_options]).to eq('kj'   => '2hv',
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
          }.to raise_error(Bolt::CLIError, /No such file/)
        end
      end

      it "reads json from stdin when --params is just '-'" do
        json_args = '{"kj":"2hv","iuhg":"iube","2whf":"lcv"}'
        cli = Bolt::CLI.new(%w[plan run my::plan --params - --modulepath .])
        allow(STDIN).to receive(:read).and_return(json_args)
        result = cli.parse
        expect(result[:task_options]).to eq('kj'   => '2hv',
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
    end

    describe "execute" do
      let(:executor) { double('executor', noop: false) }
      let(:cli) { Bolt::CLI.new({}) }
      let(:cli_logger) { Logging.logger[cli] }
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

        outputter = Bolt::Outputter::JSON.new(output)

        allow(cli).to receive(:outputter).and_return(outputter)
      end

      it "traps SIGINT early", :signals_self do
        expect(Bolt::PAL) .to receive(:new) do
          Process.kill :INT, Process.pid
          sync_thread.join(1) # give ruby some time to handle the signal
          raise 'early exit'
        end

        allow(cli_logger).to receive(:info)
        expect(cli_logger).to receive(:info).with(
          'Exiting after receiving SIGINT signal.'
        )
        expect(cli).to receive(:exit!) do
          sync_thread.kill
        end

        expect { cli.execute(mode: 'plan') }.to raise_error('early exit')
      end

      context 'when running a command' do
        let(:options) {
          {
            targets: targets,
            mode: 'command',
            action: 'run',
            object: 'whoami'
          }
        }

        it "executes the 'whoami' command" do
          expect(executor)
            .to receive(:run_command)
            .with(targets, 'whoami')
            .and_return(Bolt::ResultSet.new([]))

          expect(cli.execute(options)).to eq(0)
          expect(JSON.parse(output.string)).to be
        end

        it "returns 2 if any node fails" do
          expect(executor)
            .to receive(:run_command)
            .with(targets, 'whoami')
            .and_return(fail_set)

          expect(cli.execute(options)).to eq(2)
        end

        it "traps SIGINT", :signals_self do
          expect(executor).to receive(:run_command).with(targets, 'whoami') do
            Process.kill :INT, Process.pid
            sync_thread.join(1) # give ruby some time to handle the signal
            Bolt::ResultSet.new([])
          end

          allow(cli_logger).to receive(:info)
          expect(cli_logger).to receive(:info).with(
            'Exiting after receiving SIGINT signal. There may be processes left executing on some nodes.'
          )
          expect(cli).to receive(:exit!) do
            sync_thread.kill
          end

          cli.execute(options)
        end
      end

      context "when running a script" do
        let(:script) { 'bar.sh' }
        let(:options) {
          { targets: targets, mode: 'script', action: 'run', object: script,
            leftovers: [] }
        }

        it "runs a script" do
          stub_file(script)

          expect(executor)
            .to receive(:run_script)
            .with(targets, script, [])
            .and_return(Bolt::ResultSet.new([]))

          expect(cli.execute(options)).to eq(0)
          expect(JSON.parse(output.string)).to be
        end

        it "errors for non-existent scripts" do
          stub_non_existent_file(script)

          expect { cli.execute(options) }.to raise_error(
            Bolt::CLIError, /The script '#{script}' does not exist/
          )
          expect(JSON.parse(output.string)).to be
        end

        it "errors for unreadable scripts" do
          stub_unreadable_file(script)

          expect { cli.execute(options) }.to raise_error(
            Bolt::CLIError, /The script '#{script}' is unreadable/
          )
          expect(JSON.parse(output.string)).to be
        end

        it "errors for scripts that aren't files" do
          stub_directory(script)

          expect { cli.execute(options) }.to raise_error(
            Bolt::CLIError, /The script '#{script}' is not a file/
          )
          expect(JSON.parse(output.string)).to be
        end

        it "returns 2 if any node fails" do
          stub_file(script)
          expect(executor).to receive(:run_script)
            .with(targets, script, [])
            .and_return(fail_set)

          expect(cli.execute(options)).to eq(2)
        end

        it "traps SIGINT", :signals_self do
          stub_file(script)

          expect(executor).to receive(:run_script).with(targets, script, []) do
            Process.kill :INT, Process.pid
            sync_thread.join(1) # give ruby some time to handle the signal
            Bolt::ResultSet.new([])
          end

          allow(cli_logger).to receive(:info)
          expect(cli_logger).to receive(:info).with(
            'Exiting after receiving SIGINT signal. There may be processes left executing on some nodes.'
          )
          expect(cli).to receive(:exit!) do
            sync_thread.kill
          end

          cli.execute(options)
        end
      end

      context "when showing available tasks", :reset_puppet_settings do
        before :each do
          cli.config.modulepath = [File.join(__FILE__, '../../fixtures/modules')]
        end

        it "lists tasks with description" do
          options = {
            mode: 'task',
            action: 'show'
          }
          cli.execute(options)
          tasks = JSON.parse(output.string)
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

        it "shows an individual task data" do
          task_name = 'sample::params'
          options = {
            mode: 'task',
            action: 'show',
            object: task_name
          }
          cli.execute(options)
          json = JSON.parse(output.string)
          json.delete('executable')
          expect(json).to eq(
            "name" => "sample::params",
            "description" => "Task with parameters",
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
                "type" => "Optional[Integer[-5, 5]]"
              },
              "no_type" => {
                "description" => "A parameter without a type",
                'type' => 'Any'
              }
            },
            "supports_noop" => true
          )
        end
      end

      context "when available tasks include an error", :reset_puppet_settings do
        before :each do
          cli.config.modulepath = [File.join(__FILE__, '../../fixtures/invalid_mods')]
        end

        it "task show prints a warning but shows other valid tasks" do
          options = {
            mode: 'task',
            action: 'show'
          }
          cli.execute(options)
          json = JSON.parse(output.string)
          expect(json).to eq([['sample::ok', nil]])

          expect(@puppet_logs.first.message).to match(/unexpected token.*params\.json/m)
        end
      end

      context "when the task is not in the modulepath", :reset_puppet_settings do
        before :each do
          cli.config.modulepath = [File.join(__FILE__, '../../fixtures/modules')]
        end

        it "task show displays an error" do
          options = {
            mode: 'task',
            action: 'show',
            object: 'abcdefg'
          }
          expect {
            cli.execute(options)
          }.to raise_error(
            Bolt::CLIError,
            "Could not find task with name abcdefg. Use 'bolt task show' for a list of available tasks."
          )
        end
      end

      context "when showing available plans", :reset_puppet_settings do
        before :each do
          cli.config.modulepath = [File.join(__FILE__, '../../fixtures/modules')]
        end

        it "lists plans" do
          options = {
            mode: 'plan',
            action: 'show'
          }
          cli.execute(options)
          plan_list = JSON.parse(output.string)
          [
            ['sample'],
            ['sample::single_task'],
            ['sample::three_tasks'],
            ['sample::two_tasks']
          ].each do |plan|
            expect(plan_list).to include(plan)
          end
        end

        it "shows an individual plan data" do
          plan_name = 'sample::optional_params_task'
          options = {
            mode: 'plan',
            action: 'show',
            object: plan_name
          }
          cli.execute(options)
          json = JSON.parse(output.string)
          expect(json).to eq(
            "name" => "sample::optional_params_task",
            "parameters" => [
              {
                "name" => "param_mandatory",
                "type" => "String"
              },
              {
                "name" => "param_optional",
                "type" => "Optional[String]"
              },
              {
                "name" => "param_with_default_value",
                "type" => "String",
                "default_value" => nil
              }
            ]
          )
        end
      end

      context "when available plans include an error", :reset_puppet_settings do
        before :each do
          cli.config.modulepath = [File.join(__FILE__, '../../fixtures/invalid_mods')]
        end

        it "plan show prints a warning but shows other valid plans" do
          options = {
            mode: 'plan',
            action: 'show'
          }

          cli.execute(options)
          json = JSON.parse(output.string)
          expect(json).to eq([['sample::ok']])

          expect(@puppet_logs.first.message).to match(/^Syntax error at.*single_task.pp/m)
        end

        it "plan run displays an error" do
          plan_name = 'sample::single_task'
          plan_params = { 'nodes' => targets.map(&:host).join(',') }

          options = {
            mode: 'plan',
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
            mode: 'plan',
            action: 'show',
            object: 'abcdefg'
          }
          expect {
            cli.execute(options)
          }.to raise_error(
            Bolt::CLIError,
            "Could not find plan with name abcdefg. Use 'bolt plan show' for a list of available plans."
          )
        end
      end

      context "when running a task", :reset_puppet_settings do
        let(:task_name) { 'sample::echo' }
        let(:task_params) { { 'message' => 'hi' } }
        let(:options) {
          {
            targets: targets,
            mode: 'task',
            action: 'run',
            object: task_name,
            task_options: task_params
          }
        }
        let(:input_method) { 'both' }

        before :each do
          cli.config.modulepath = [File.join(__FILE__, '../../fixtures/modules')]
        end

        it "runs a task given a name" do
          expect(executor)
            .to receive(:run_task)
            .with(
              targets,
              %r{modules/sample/tasks/echo.sh$}, input_method, task_params, {}
            ).and_return(Bolt::ResultSet.new([]))

          expect(cli.execute(options)).to eq(0)
          expect(JSON.parse(output.string)).to be
        end

        it "returns 2 if any node fails" do
          expect(executor)
            .to receive(:run_task)
            .with(
              targets,
              %r{modules/sample/tasks/echo.sh$}, input_method, task_params, {}
            ).and_return(fail_set)

          expect(cli.execute(options)).to eq(2)
        end

        it "errors for non-existent modules" do
          task_name.replace 'dne::task1'

          expect { cli.execute(options) }.to raise_error(
            Bolt::CLIError, /Task not found: dne::task1/
          )
          expect(JSON.parse(output.string)).to be
        end

        it "errors for non-existent tasks" do
          task_name.replace 'sample::dne'

          expect { cli.execute(options) }.to raise_error(
            Bolt::CLIError, /Task not found: sample::dne/
          )
          expect(JSON.parse(output.string)).to be
        end

        it "raises errors from the executor" do
          task_params.clear

          expect(executor)
            .to receive(:run_task)
            .with(
              targets,
              %r{modules/sample/tasks/echo.sh$}, input_method, {}, {}
            ).and_raise("Could not connect to target")

          expect { cli.execute(options) }.to raise_error(/Could not connect to target/)
        end

        it "runs an init task given a module name" do
          task_name.replace 'sample'

          expect(executor)
            .to receive(:run_task)
            .with(
              targets,
              %r{modules/sample/tasks/init.sh$}, input_method, task_params, {}
            ).and_return(Bolt::ResultSet.new([]))

          cli.execute(options)
          expect(JSON.parse(output.string)).to be
        end

        it "runs a task passing input on stdin" do
          task_name.replace 'sample::stdin'
          input_method = 'stdin'

          expect(executor)
            .to receive(:run_task)
            .with(targets,
                  %r{modules/sample/tasks/stdin.sh$}, input_method, task_params, {})
            .and_return(Bolt::ResultSet.new([]))

          cli.execute(options)
          expect(JSON.parse(output.string)).to be
        end

        it "runs a powershell task passing input on stdin" do
          task_name.replace 'sample::winstdin'
          input_method = 'stdin'

          expect(executor)
            .to receive(:run_task)
            .with(targets,
                  %r{modules/sample/tasks/winstdin.ps1$}, input_method, task_params, {})
            .and_return(Bolt::ResultSet.new([]))

          cli.execute(options)
          expect(JSON.parse(output.string)).to be
        end

        it "traps SIGINT", :signals_self do
          expect(executor)
            .to receive(:run_task)
            .with(targets, %r{modules/sample/tasks/echo.sh$}, input_method, task_params, {}) do
              Process.kill :INT, Process.pid
              sync_thread.join(1) # give ruby some time to handle the signal
              Bolt::ResultSet.new([])
            end

          allow(cli_logger).to receive(:info)
          expect(cli_logger).to receive(:info).with(
            'Exiting after receiving SIGINT signal. There may be processes left executing on some nodes.'
          )
          expect(cli).to receive(:exit!) do
            sync_thread.kill
          end

          cli.execute(options)
        end

        describe 'task parameters validation' do
          let(:task_name) { 'sample::params' }
          let(:task_params) { {} }
          let(:input_method) { 'stdin' }

          it "errors when unknown parameters are specified" do
            task_params.merge!(
              'foo' => nil,
              'bar' => nil
            )

            expect { cli.execute(options) }.to raise_error(
              Bolt::CLIError,
              /Task\ sample::params:\n
               \s*has\ no\ parameter\ named\ 'foo'\n
               \s*has\ no\ parameter\ named\ 'bar'/x
            )
            expect(JSON.parse(output.string)).to be
          end

          it "errors when required parameters are not specified" do
            task_params['mandatory_string'] = 'str'

            expect { cli.execute(options) }.to raise_error(
              Bolt::CLIError,
              /Task\ sample::params:\n
               \s*expects\ a\ value\ for\ parameter\ 'mandatory_integer'\n
               \s*expects\ a\ value\ for\ parameter\ 'mandatory_boolean'/x
            )
            expect(JSON.parse(output.string)).to be
          end

          it "errors when the specified parameter values don't match the expected data types" do
            task_params.merge!(
              'mandatory_string'  => 'str',
              'mandatory_integer' => 10,
              'mandatory_boolean' => 'str',
              'non_empty_string'  => 'foo',
              'optional_string'   => 10
            )

            expect { cli.execute(options) }.to raise_error(
              Bolt::CLIError,
              /Task\ sample::params:\n
               \s*parameter\ 'mandatory_boolean'\ expects\ a\ Boolean\ value,\ got\ String\n
               \s*parameter\ 'optional_string'\ expects\ a\ value\ of\ type\ Undef\ or\ String,
                                              \ got\ Integer/x
            )
            expect(JSON.parse(output.string)).to be
          end

          it "errors when the specified parameter values are outside of the expected ranges" do
            task_params.merge!(
              'mandatory_string'  => '0123456789a',
              'mandatory_integer' => 10,
              'mandatory_boolean' => true,
              'non_empty_string'  => 'foo',
              'optional_integer'  => 10
            )

            expect { cli.execute(options) }.to raise_error(
              Bolt::CLIError,
              /Task\ sample::params:\n
               \s*parameter\ 'mandatory_string'\ expects\ a\ String\[1,\ 10\]\ value,\ got\ String\n
               \s*parameter\ 'optional_integer'\ expects\ a\ value\ of\ type\ Undef\ or\ Integer\[-5,\ 5\],
                                               \ got\ Integer\[10,\ 10\]/x
            )
            expect(JSON.parse(output.string)).to be
          end

          it "runs the task when the specified parameters are successfully validated" do
            expect(executor)
              .to receive(:run_task)
              .with(targets,
                    %r{modules/sample/tasks/params.sh$}, input_method, task_params, {})
              .and_return(Bolt::ResultSet.new([]))
            task_params.merge!(
              'mandatory_string'  => ' ',
              'mandatory_integer' => 0,
              'mandatory_boolean' => false,
              'non_empty_string'  => 'foo'
            )

            cli.execute(options)
            expect(JSON.parse(output.string)).to be
          end
        end
      end

      context "when running a plan", :reset_puppet_settings do
        let(:plan_name) { 'sample::single_task' }
        let(:plan_params) { { 'nodes' => targets.map(&:host).join(',') } }
        let(:options) {
          {
            targets: targets,
            mode: 'plan',
            action: 'run',
            object: plan_name,
            task_options: plan_params
          }
        }
        let(:input_method) { 'both' }

        before :each do
          cli.config.modulepath = [File.join(__FILE__, '../../fixtures/modules')]
        end

        it "formats results of a passing task" do
          expect(executor)
            .to receive(:run_task)
            .with(
              targets,
              %r{modules/sample/tasks/echo.sh$}, input_method, { 'message' => 'hi there' }, {}
            ).and_return(Bolt::ResultSet.new([Bolt::Result.for_task(target, 'yes', '', 0)]))

          cli.execute(options)
          expect(JSON.parse(output.string)).to eq(
            [{ 'node' => 'foo', 'status' => 'success', 'result' => { '_output' => 'yes' } }]
          )
        end

        it "raises errors from the executor" do
          expect(executor)
            .to receive(:run_task)
            .with(
              targets,
              %r{modules/sample/tasks/echo.sh$}, input_method, { 'message' => 'hi there' }, {}
            ).and_raise("Could not connect to target")

          expect { cli.execute(options) }.to raise_error(/Could not connect to target/)
        end

        it "formats results of a failing task" do
          expect(executor)
            .to receive(:run_task)
            .with(
              targets,
              %r{modules/sample/tasks/echo.sh$}, input_method, { 'message' => 'hi there' }, {}
            ).and_return(Bolt::ResultSet.new([Bolt::Result.for_task(target, 'no', '', 1)]))

          cli.execute(options)
          expect(JSON.parse(output.string)).to eq(
            [
              {
                'node' => 'foo',
                'status' => 'failure',
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

        it "traps SIGINT", :signals_self do
          expect(executor)
            .to receive(:run_task)
            .with(targets, %r{modules/sample/tasks/echo.sh$}, input_method, { 'message' => 'hi there' }, {}) do
              Process.kill :INT, Process.pid
              sync_thread.join(1) # give ruby some time to handle the signal
              Bolt::ResultSet.new([])
            end

          allow(cli_logger).to receive(:info)
          expect(cli_logger).to receive(:info).with(
            'Exiting after receiving SIGINT signal. There may be processes left executing on some nodes.'
          )
          expect(cli).to receive(:exit!) do
            sync_thread.kill
          end

          cli.execute(options)
        end
      end

      describe "file uploading" do
        let(:source) { '/path/to/local' }
        let(:dest) { '/path/to/remote' }
        let(:options) {
          {
            targets: targets,
            mode: 'file',
            action: 'upload',
            object: source,
            leftovers: [dest]
          }
        }

        it "uploads a file via scp" do
          stub_file(source)

          expect(executor)
            .to receive(:file_upload)
            .with(targets, source, dest)
            .and_return(Bolt::ResultSet.new([]))

          cli.execute(options)
          expect(JSON.parse(output.string)).to be
        end

        it "returns 2 if any node fails" do
          stub_file(source)

          expect(executor)
            .to receive(:file_upload)
            .with(targets, source, dest)
            .and_return(fail_set)

          expect(cli.execute(options)).to eq(2)
        end

        it "raises if the local file doesn't exist" do
          stub_non_existent_file(source)

          expect { cli.execute(options) }.to raise_error(
            Bolt::CLIError, /The source file '#{source}' does not exist/
          )
          expect(JSON.parse(output.string)).to be
        end

        it "errors if the local file is unreadable" do
          stub_unreadable_file(source)

          expect { cli.execute(options) }.to raise_error(
            Bolt::CLIError, /The source file '#{source}' is unreadable/
          )
          expect(JSON.parse(output.string)).to be
        end

        it "errors if the local file is a directory" do
          stub_directory(source)

          expect { cli.execute(options) }.to raise_error(
            Bolt::CLIError, /The source file '#{source}' is not a file/
          )
          expect(JSON.parse(output.string)).to be
        end
      end
    end

    describe "execute with noop" do
      let(:executor) { double('executor', noop: true) }
      let(:cli) { Bolt::CLI.new({}) }
      let(:targets) { [target] }
      let(:output) { StringIO.new }

      before :each do
        allow(Bolt::Executor).to receive(:new).with(config, true).and_return(executor)

        outputter = Bolt::Outputter::JSON.new(output)

        allow(cli).to receive(:outputter).and_return(outputter)
      end

      context "when running a task", :reset_puppet_settings do
        let(:task_name) { 'sample::noop' }
        let(:task_params) { { 'message' => 'hi' } }
        let(:options) {
          {
            targets: targets,
            mode: 'task',
            action: 'run',
            object: task_name,
            task_options: task_params,
            noop: true
          }
        }
        let(:input_method) { 'both' }

        before :each do
          cli.config.modulepath = [File.join(__FILE__, '../../fixtures/modules')]
        end

        it "runs a task that supports noop" do
          expect(executor)
            .to receive(:run_task)
            .with(targets,
                  %r{modules/sample/tasks/noop.sh$}, input_method, task_params.merge('_noop' => true), {})
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
  end

  describe 'configfile' do
    let(:configdir) { File.join(__dir__, '..', 'fixtures', 'configs') }
    let(:complete_config) do
      { 'modulepath' => "/foo/bar#{File::PATH_SEPARATOR}/baz/qux",
        'inventoryfile' => File.join(__dir__, '..', 'fixtures', 'inventory', 'empty.yml'),
        'concurrency' => 14,
        'format' => 'json',
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
          'ssl' => false
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
        cli = Bolt::CLI.new(%W[command run --configfile #{conf.path} --nodes foo --no-host-key-check])
        cli.parse
        expect(cli.config[:modulepath]).to eq(['/foo/bar', '/baz/qux'])
      end
    end

    it 'reads concurrency' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run --configfile #{conf.path} --nodes foo --no-host-key-check])
        cli.parse
        expect(cli.config[:concurrency]).to eq(14)
      end
    end

    it 'reads format' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run --configfile #{conf.path} --nodes foo --no-host-key-check])
        cli.parse
        expect(cli.config[:format]).to eq('json')
      end
    end

    it 'reads private-key for ssh' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run --configfile #{conf.path} --nodes foo --no-host-key-check])
        cli.parse
        expect(cli.config[:transports][:ssh][:key]).to eq('/bar/foo')
      end
    end

    it 'reads host_key_check for ssh' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run --configfile #{conf.path} --nodes foo])
        cli.parse
        expect(cli.config[:transports][:ssh][:host_key_check]).to eq(false)
      end
    end

    it 'reads run-as for ssh' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run --configfile #{conf.path} --nodes foo --password bar --no-host-key-check])
        cli.parse
        expect(cli.config[:transports][:ssh][:run_as]).to eq('Fakey McFakerson')
      end
    end

    it 'reads separate connect-timeout for ssh and winrm' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run --configfile #{conf.path} --nodes foo --no-host-key-check --no-ssl])
        cli.parse
        expect(cli.config[:transports][:ssh][:connect_timeout]).to eq(4)
        expect(cli.config[:transports][:winrm][:connect_timeout]).to eq(7)
      end
    end

    it 'reads ssl for winrm' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run --configfile #{conf.path} --nodes foo])
        cli.parse
        expect(cli.config[:transports][:winrm][:ssl]).to eq(false)
      end
    end

    it 'reads extensions for winrm' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run --configfile #{conf.path} --nodes foo --no-ssl])
        cli.parse
        expect(cli.config[:transports][:winrm][:extensions]).to eq(['.py', '.bat'])
      end
    end

    it 'transforms extensions for winrm' do
      new_config = complete_config.clone
      new_config['winrm'] = { 'extensions' => 'py' }
      with_tempfile_containing('conf', YAML.dump(new_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run --configfile #{conf.path} --nodes foo --no-ssl])
        cli.parse
        expect(cli.config[:transports][:winrm][:extensions]).to eq(['.py'])
      end
    end

    it 'reads task environment for pcp' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run --configfile #{conf.path} --nodes foo])
        cli.parse
        expect(cli.config[:transports][:pcp][:orch_task_environment]).to eq('testenv')
      end
    end

    it 'reads service url for pcp' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run --configfile #{conf.path} --nodes foo])
        cli.parse
        expect(cli.config[:transports][:pcp][:service_url]).to eql('http://foo.org')
      end
    end

    it 'reads token file for pcp' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run --configfile #{conf.path} --nodes foo])
        cli.parse
        expect(cli.config[:transports][:pcp][:token_file]).to eql('/path/to/token')
      end
    end

    it 'reads separate cacert file for pcp and winrm' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run --configfile #{conf.path} --nodes foo --no-host-key-check --no-ssl])
        cli.parse
        expect(cli.config[:transports][:pcp][:cacert]).to eql('/path/to/cacert')
        expect(cli.config[:transports][:winrm][:cacert]).to eql('/path/to/winrm-cacert')
      end
    end

    it 'CLI flags override config' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run --configfile #{conf.path} --nodes foo --concurrency 12])
        cli.parse
        expect(cli.config.concurrency).to eq(12)
      end
    end

    it 'raises an error if a config file is specified and invalid' do
      cli = Bolt::CLI.new(%W[command run --configfile #{File.join(configdir, 'invalid.yml')} --nodes foo])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /Could not parse/)
    end
  end

  describe 'inventoryfile' do
    let(:inventorydir) { File.join(__dir__, '..', 'fixtures', 'configs') }

    it 'raises an error if a inventory file is specified and invalid' do
      cli = Bolt::CLI.new(%W[command run --inventoryfile #{File.join(inventorydir, 'invalid.yml')} --nodes foo])
      expect {
        cli.parse
      }.to raise_error(Bolt::Error, /Could not parse/)
    end
  end
end
