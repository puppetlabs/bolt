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
  let(:inventory) { Bolt::Inventory.empty }
  let(:target) { inventory.get_target('foo') }

  before(:each) do
    outputter = Bolt::Outputter::Human.new(false, false, false, StringIO.new)

    allow_any_instance_of(Bolt::CLI).to receive(:outputter).and_return(outputter)
    allow_any_instance_of(Bolt::CLI).to receive(:warn)
    # Don't print error messages to the console
    allow($stdout).to receive(:puts)

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
      }.to raise_error(Bolt::CLIError, /Expected subcommand 'bolt2' to be one of/)
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

        it 'accepts puppetfile' do
          cli = Bolt::CLI.new(%w[help puppetfile])
          expect {
            expect {
              cli.parse
            }.to raise_error(Bolt::CLIExit)
          }.to output(/ACTIONS.*install.*show-modules/m).to_stdout
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
        allow(STDIN).to receive(:read).and_return(nodes)
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
        allow(STDIN).to receive(:noecho).and_return('opensesame')
        allow(STDERR).to receive(:print).with('Please enter your password: ')
        allow(STDERR).to receive(:puts)
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
        expect(Bolt::Logger).to receive(:configure).with({ 'console' => { level: :debug } }, true)

        cli = Bolt::CLI.new(%w[command run uptime --targets foo --debug --verbose])
        cli.parse
      end

      it "errors when debug and log-level are both set" do
        cli = Bolt::CLI.new(%w[command run uptime --targets foo --debug --log-level notice])
        expect { cli.parse }.to raise_error(Bolt::CLIError, /Only one of '--debug' or '--log-level' may be specified/)
      end

      it "warns when using debug" do
        expect(Bolt::Logger).to receive(:deprecation_warning)
          .with(anything, /Command line option '--debug' is deprecated/)
        cli = Bolt::CLI.new(%w[command run uptime --targets foo --debug])
        cli.parse
      end

      it "log-level sets the log option" do
        expect(Bolt::Logger).to receive(:configure).with({ 'console' => { level: 'notice' } }, true)

        cli = Bolt::CLI.new(%w[command run uptime --targets foo --log-level notice])
        cli.parse
      end

      it "raises a Bolt error when the level is a stringified integer" do
        cli = Bolt::CLI.new(%w[command run uptime --targets foo --log-level 42])
        expect { cli.parse }.to raise_error(Bolt::ValidationError, /level of log console must be one of/)
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

    describe "puppetfile" do
      let(:puppetfile) { File.expand_path('/path/to/Puppetfile') }
      let(:cli) { Bolt::CLI.new(%W[puppetfile install --puppetfile #{puppetfile}]) }

      it 'uses a specified Puppetfile' do
        cli.parse
        expect(cli.config.puppetfile.to_s).to eq(puppetfile)
      end
    end

    describe "modules" do
      let(:modules) { 'puppetlabs-apt,puppetlabs-stdlib' }
      let(:cli)     { Bolt::CLI.new(%W[project init --modules #{modules}]) }

      it 'accepts a comma-separated list of modules' do
        expect(cli.parse).to include(modules: %w[puppetlabs-apt puppetlabs-stdlib])
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
        allow(STDIN).to receive(:noecho).and_return('opensesame')
        allow(STDERR).to receive(:print).with('Please enter your privilege escalation password: ')
        allow(STDERR).to receive(:puts)
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
        allow(STDIN).to receive(:read).and_return(json_args)
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
        allow(cli).to receive(:config).and_return(Bolt::Config.default)
        allow(Bolt::Executor).to receive(:new).and_return(executor)
        allow(executor).to receive(:log_plan) { |_plan_name, &block| block.call }
        allow(executor).to receive(:run_plan) do |scope, plan, params|
          plan.call_by_name_with_scope(scope, params, true)
        end

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

        it "only includes tasks set in bolt-project.yaml" do
          mocks = {
            type: '',
            resource_types: '',
            tasks: ['facts'],
            project_file?: true,
            name: nil,
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
            "description" => "Demonstrates plans with optional parameters",
            "module_dir" => File.absolute_path(File.join(__dir__, "..", "fixtures", "modules", "sample")),
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
            "module_dir" => File.absolute_path(File.join(__dir__, "..", "fixtures", "modules", "sample")),
            "description" => nil,
            "parameters" => {
              "oops" => {
                "type" => "String",
                "default_value" => "typo",
                "sensitive" => false
              }
            }
          )
          expected_log = /The documented parameter 'not_oops' does not exist in plan signature/m
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
            "module_dir" => File.absolute_path(File.join(__dir__, "..", "fixtures", "modules", "sample")),
            "parameters" => {
              "nodes" => {
                "type" => "TargetSpec",
                "default_value" => nil,
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
                'foo' => 'foo',
                'bar' => 'bar'
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
              let(:target) { inventory.get_target('pcp://foo') }
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
          cli.config.modulepath = [File.join(__FILE__, '../../fixtures/modules')]
        end

        context 'with TargetSpec $nodes plan param' do
          it "uses the nodes passed using the --targets option(s) as the 'nodes' plan parameter" do
            plan_params.clear
            options[:targets] = targets.map(&:host)

            expect(executor)
              .to receive(:run_task)
              .with(targets, task_t, { 'message' => 'hi there' }, kind_of(Hash))
              .and_return(Bolt::ResultSet.new([Bolt::Result.for_task(target, 'yes', '', 0, 'some_task')]))

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
              .with(targets, task_t, { 'message' => 'hi there' }, kind_of(Hash))
              .and_return(Bolt::ResultSet.new([Bolt::Result.for_task(target, 'yes', '', 0, 'some_task')]))

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
            .with(targets, task_t, { 'message' => 'hi there' }, kind_of(Hash))
            .and_return(Bolt::ResultSet.new([Bolt::Result.for_task(target, 'yes', '', 0, 'some_task')]))

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
            .with(targets, task_t, { 'message' => 'hi there' }, kind_of(Hash))
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
            .with(targets, task_t, { 'message' => 'hi there' }, kind_of(Hash))
            .and_return(Bolt::ResultSet.new([Bolt::Result.for_task(target, 'no', '', 1, 'some_task')]))

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
                                                     true,
                                                     anything).and_return(executor)

        plugins = Bolt::Plugin.setup(Bolt::Config.default, nil)
        allow(cli).to receive(:plugins).and_return(plugins)

        outputter = Bolt::Outputter::JSON.new(false, false, false, output)
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
        allow(cli).to receive(:config).and_return(Bolt::Config.default)
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
          subcommand: 'apply',
          targets: 'foo'
        }
      }
      let(:output) { StringIO.new }
      let(:cli) { Bolt::CLI.new([]) }

      before :each do
        allow(cli).to receive(:outputter).and_return(Bolt::Outputter::JSON.new(false, false, false, output))
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

    it 'loads from BOLT_PROJECT environment variable over --configfile' do
      cli = Bolt::CLI.new(%w[command run uptime --configfile /foo/bar --targets foo])
      cli.parse

      expect(cli.config.project.path).to eq(pathname)
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

    before(:each) do
      allow(Bolt::Util).to receive(:validate_file).and_return(true)
    end

    it 'reads modulepath' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --targets foo --no-host-key-check])
        cli.parse
        expect(cli.config.modulepath).to eq(modulepath)
      end
    end

    it 'reads concurrency' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --targets foo --no-host-key-check])
        cli.parse
        expect(cli.config.concurrency).to eq(14)
      end
    end

    it 'reads compile-concurrency' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --targets foo --no-host-key-check])
        cli.parse
        expect(cli.config.compile_concurrency).to eq(2)
      end
    end

    it 'reads format' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --targets foo --no-host-key-check])
        cli.parse
        expect(cli.config.format).to eq('json')
      end
    end

    it 'reads log file' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --targets foo --no-host-key-check])
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
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --targets foo --no-host-key-check])
        cli.parse
        expect(cli.config.transports['ssh']['private-key']).to match(%r{/bar/foo\z})
      end
    end

    it 'reads host-key-check for ssh' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --targets foo])
        cli.parse
        expect(cli.config.transports['ssh']['host-key-check']).to eq(false)
      end
    end

    it 'reads run-as for ssh' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(
          %W[command run r --configfile #{conf.path} --targets foo --password bar --no-host-key-check]
        )
        cli.parse
        expect(cli.config.transports['ssh']['run-as']).to eq('Fakey McFakerson')
      end
    end

    it 'reads separate connect-timeout for ssh and winrm' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --targets foo --no-host-key-check --no-ssl])
        cli.parse
        expect(cli.config.transports['ssh']['connect-timeout']).to eq(4)
        expect(cli.config.transports['winrm']['connect-timeout']).to eq(7)
      end
    end

    it 'reads ssl for winrm' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --targets foo])
        cli.parse
        expect(cli.config.transports['winrm']['ssl']).to eq(false)
      end
    end

    it 'reads ssl-verify for winrm' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --targets foo])
        cli.parse
        expect(cli.config.transports['winrm']['ssl-verify']).to eq(false)
      end
    end

    it 'reads extensions for winrm' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --targets foo --no-ssl])
        cli.parse
        expect(cli.config.transports['winrm']['extensions']).to eq(['.py', '.bat'])
      end
    end

    it 'reads task environment for pcp' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --targets foo])
        cli.parse
        expect(cli.config.transports['pcp']['task-environment']).to eq('testenv')
      end
    end

    it 'reads service url for pcp' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --targets foo])
        cli.parse
        expect(cli.config.transports['pcp']['service-url']).to eql('http://foo.org')
      end
    end

    it 'reads token file for pcp' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --targets foo])
        cli.parse
        expect(cli.config.transports['pcp']['token-file']).to match(%r{/path/to/token\z})
      end
    end

    it 'reads separate cacert file for pcp and winrm' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --targets foo --no-host-key-check --no-ssl])
        cli.parse
        expect(cli.config.transports['pcp']['cacert']).to match(%r{/path/to/cacert\z})
        expect(cli.config.transports['winrm']['cacert']).to match(%r{/path/to/winrm-cacert\z})
      end
    end

    it 'CLI flags override config' do
      with_tempfile_containing('conf', YAML.dump(complete_config)) do |conf|
        cli = Bolt::CLI.new(%W[command run uptime --configfile #{conf.path} --targets foo --concurrency 12])
        cli.parse
        expect(cli.config.concurrency).to eq(12)
      end
    end

    it 'raises an error if a config file is specified and invalid' do
      cli = Bolt::CLI.new(%W[command run uptime --configfile #{File.join(configdir, 'invalid.yml')} --targets foo])
      expect {
        cli.parse
      }.to raise_error(Bolt::FileError, /Could not parse/)
    end
  end

  describe 'inventoryfile' do
    let(:inventorydir) { File.join(__dir__, '..', 'fixtures', 'configs') }

    it 'raises an error if an inventory file is specified and invalid' do
      cli = Bolt::CLI.new(
        %W[command run uptime --inventoryfile #{File.join(inventorydir, 'invalid.yml')} --targets foo]
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
        cli = Bolt::CLI.new(%W[command run id --inventoryfile #{File.join(inventorydir, 'invalid.yml')} --targets foo])
        expect {
          cli.parse
        }.to raise_error(Bolt::Error, /BOLT_INVENTORY is set/)
      end
    end
  end

  describe 'project' do
    context 'migrate' do
      let(:inventory_v1) do
        {
          "version" => 1,
          "name" => "all",
          "groups" => [
            {
              "name" => "group1",
              "nodes" => [
                {
                  "name" => "target1",
                  "facts" => {
                    "name" => "foo"
                  }
                }
              ]
            },
            {
              "name" => "group2",
              "nodes" => [
                {
                  "name" => "target2"
                }
              ]
            }
          ]
        }
      end
      let(:inventory_v2) do
        {
          "name" => "all",
          "groups" => [
            {
              "name" => "group1",
              "targets" => [
                {
                  "uri" => "target1",
                  "facts" => {
                    "name" => "foo"
                  }
                }
              ]
            },
            {
              "name" => "group2",
              "targets" => [
                {
                  "uri" => "target2"
                }
              ]
            }
          ]
        }
      end

      it 'migrates inventory v1 to inventory v2' do
        with_tempfile_containing('inventory', YAML.dump(inventory_v1)) do |file|
          cli = Bolt::CLI.new(%W[project migrate --inventoryfile #{file.path}])
          cli.execute(cli.parse)
          expect(YAML.load_file(file)).to eq(inventory_v2)
        end
      end

      it 'does nothing when using inventory v2' do
        cli = Bolt::CLI.new([])
        expect(cli.migrate_group(inventory_v2)).to eq(false)
      end
    end

    context 'init' do
      it 'creates a new project at the specified path' do
        Dir.mktmpdir do |dir|
          file = File.join(dir, 'bolt.yaml')
          cli = Bolt::CLI.new(%W[project init #{dir}])
          cli.execute(cli.parse)
          expect(File.file?(file)).to be
        end
      end

      it 'creates a new project in the current working directory' do
        Dir.mktmpdir do |dir|
          file = File.join(dir, 'bolt.yaml')
          cli = Bolt::CLI.new(%w[project init])
          Dir.chdir(dir) { cli.execute(cli.parse) }
          expect(File.file?(file)).to be
        end
      end

      it 'warns when a bolt.yaml already exists' do
        Dir.mktmpdir do |dir|
          config = File.join(dir, 'bolt.yaml')
          cli    = Bolt::CLI.new(%W[project init #{dir}])

          FileUtils.touch(config)
          cli.execute(cli.parse)

          expect(@log_output.readlines).to include(/Found existing project directory at #{dir}/)
        end
      end

      context 'with modules' do
        it 'creates a Puppetfile and installs modules with dependencies' do
          # Create the tmpdir relative to the current dir to handle issues with tempfiles on Windows CI
          Dir.mktmpdir(nil, Dir.pwd) do |dir|
            puppetfile = File.join(dir, 'Puppetfile')
            modulepath = File.join(dir, 'modules')

            cli = Bolt::CLI.new(%W[project init #{dir} --modules puppetlabs-apt])
            cli.execute(cli.parse)

            expect(File.file?(puppetfile)).to be
            expect(File.read(puppetfile).split("\n")).to match_array([/mod 'puppetlabs-apt'/,
                                                                      /mod 'puppetlabs-stdlib'/,
                                                                      /mod 'puppetlabs-translate'/])

            expect(Dir.exist?(modulepath)).to be
            expect(Dir.children(modulepath)).to match_array(%w[apt stdlib translate])
          end
        end

        it 'errors when there is an existing Puppetfile' do
          Dir.mktmpdir do |dir|
            puppetfile = File.join(dir, 'Puppetfile')
            config     = File.join(dir, 'bolt.yaml')

            FileUtils.touch(puppetfile)

            cli = Bolt::CLI.new(%W[project init #{dir} --modules puppetlabs-stdlib])
            expect { cli.execute(cli.parse) }.to raise_error(Bolt::CLIError)
            expect(File.file?(config)).not_to be
          end
        end

        it 'errors with unknown module names' do
          Dir.mktmpdir do |dir|
            puppetfile = File.join(dir, 'Puppetfile')
            config     = File.join(dir, 'bolt.yaml')

            cli = Bolt::CLI.new(%W[project init #{dir} --modules puppetlabs-fakemodule])
            expect { cli.execute(cli.parse) }.to raise_error(Bolt::ValidationError)
            expect(File.file?(config)).not_to be
            expect(File.file?(puppetfile)).not_to be
          end
        end
      end
    end
  end

  context 'when warning about CLI flags being overridden by inventory' do
    it "does not warn when no inventory is detected" do
      cli = Bolt::CLI.new(%w[command run whoami -t foo --password bar])
      cli.parse
      expect(@log_output.readlines.join)
        .not_to match(/CLI arguments ["password"] may be overridden by Inventory/)
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
      let(:inventoryfile) { File.join(__dir__, '..', 'fixtures', 'configs', 'empty.yml') }
      it "warns when BOLT_INVENTORY data is detected and CLI option could be overridden" do
        cli = Bolt::CLI.new(%W[command run whoami -t foo --password bar --inventoryfile #{inventoryfile}])
        cli.parse
        expect(@log_output.readlines.join)
          .to match(/CLI arguments \["password"\] may be overridden by Inventory:/)
      end
    end
  end

  it 'with bolt-project with config, warns and ignores bolt.yaml' do
    Dir.mktmpdir do |dir|
      pwd = File.join(dir, 'validname')
      FileUtils.mkdir_p(pwd)
      FileUtils.touch(File.join(pwd, 'bolt.yaml'))
      File.write(File.join(pwd, 'bolt-project.yaml'), { 'format' => 'json' }.to_yaml)

      cli = Bolt::CLI.new(%W[command run whoami -t foo --boltdir #{pwd}])
      cli.parse

      output = @log_output.readlines
      expect(output).to include(/Project-level configuration in bolt.yaml is deprecated/)
      expect(output).to include(/bolt-project.yaml contains valid config keys/)
    end
  end
end
