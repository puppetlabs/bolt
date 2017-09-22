require 'spec_helper'
require 'bolt/cli'

describe "Bolt::CLI" do
  it "generates an error message if an unknown argument is given" do
    cli = Bolt::CLI.new(%w[command run --unknown])
    expect {
      cli.parse
    }.to raise_error(Bolt::CLIError, /unknown argument '--unknown'/)
  end

  # it "includes unparsed arguments" do
  #   cli = Bolt::CLI.new(%w[exec run what --nodes foo])
  #   expect(cli.parse).to include(leftovers: %w[what])
  # end

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
    it "accepts a single node" do
      cli = Bolt::CLI.new(%w[command run --nodes foo])
      expect(cli.parse).to include(nodes: ['foo'])
    end

    it "accepts multiple nodes" do
      cli = Bolt::CLI.new(%w[command run --nodes foo,bar])
      expect(cli.parse).to include(nodes: %w[foo bar])
    end

    it "generates an error message if no nodes given" do
      cli = Bolt::CLI.new(%w[command run --nodes])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /option '--nodes' needs a parameter/)
    end

    it "generates an error message if nodes is omitted" do
      cli = Bolt::CLI.new(%w[command run])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /option --nodes must be specified/)
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
      }.to raise_error(Bolt::CLIError, /option '--user' needs a parameter/)
    end
  end

  describe "password" do
    it "accepts a password" do
      cli = Bolt::CLI.new(%w[command run --password opensesame --nodes foo])
      expect(cli.parse).to include(password: 'opensesame')
    end

    it "generates an error message if no password value is given" do
      cli = Bolt::CLI.new(%w[command run --nodes foo --password])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /option '--password' needs a parameter/)
    end
  end

  describe "modules" do
    it "accepts a modules directory" do
      cli = Bolt::CLI.new(%w[command run --modules ./modules --nodes foo])
      expect(cli.parse).to include(modules: './modules')
    end

    it "generates an error message if no value is given" do
      cli = Bolt::CLI.new(%w[command run --nodes foo --modules])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /option '--modules' needs a parameter/)
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

  describe "execute" do
    let(:executor) { double('executor') }
    let(:cli) { Bolt::CLI.new({}) }
    let(:nodes) { ['foo'] }

    before :each do
      allow(Bolt::Executor).to receive(:new).and_return(executor)
      allow(cli).to receive(:print_results)
    end

    it "executes the 'whoami' command" do
      expect(executor).to receive(:run_command).with('whoami').and_return({})

      options = {
        nodes: nodes, mode: 'command', action: 'run', object: 'whoami'
      }
      cli.execute(options)
    end

    it "runs a script" do
      expect(executor).to receive(:run_script).with('bar.sh').and_return({})

      options = {
        nodes: nodes, mode: 'script', action: 'run', object: 'bar.sh'
      }
      cli.execute(options)
    end

    it "runs a task" do
      task_path = '/path/to/task'
      task_params = { 'name' => 'apache', 'action' => 'restart' }
      input_method = 'both'

      expect(executor)
        .to receive(:run_task)
        .with(task_path, input_method, task_params)
        .and_return({})
      expect(cli).to receive(:file_exist?).with(task_path).and_return(true)

      options = {
        nodes: nodes,
        mode: 'task',
        action: 'run',
        object: task_path,
        task_options: task_params
      }
      cli.execute(options)
    end

    it "runs a task given a name" do
      task_name = 'sample::echo'
      task_params = { 'message' => 'hi' }
      input_method = 'both'

      expect(executor)
        .to receive(:run_task)
        .with(%r{modules/sample/tasks/echo.sh$}, input_method, task_params)
        .and_return({})
      expect(cli).to receive(:file_exist?).with(task_name).and_return(false)

      options = {
        nodes: nodes,
        mode: 'task',
        action: 'run',
        object: task_name,
        task_options: task_params,
        modules: File.join(__FILE__, '../../fixtures/modules')
      }
      cli.execute(options)
    end

    it "runs an init task given a module name" do
      task_name = 'sample'
      task_params = { 'message' => 'hi' }
      input_method = 'both'

      expect(executor)
        .to receive(:run_task)
        .with(%r{modules/sample/tasks/init.sh$}, input_method, task_params)
        .and_return({})
      expect(cli).to receive(:file_exist?).with(task_name).and_return(false)

      options = {
        nodes: nodes,
        mode: 'task',
        action: 'run',
        object: task_name,
        task_options: task_params,
        modules: File.join(__FILE__, '../../fixtures/modules')
      }
      cli.execute(options)
    end

    it "runs a task passing input on stdin" do
      task_name = 'sample::stdin'
      task_params = { 'message' => 'hi' }
      input_method = 'stdin'

      expect(executor)
        .to receive(:run_task)
        .with(%r{modules/sample/tasks/stdin.sh$}, input_method, task_params)
        .and_return({})
      expect(cli).to receive(:file_exist?).with(task_name).and_return(false)

      options = {
        nodes: nodes,
        mode: 'task',
        action: 'run',
        object: task_name,
        task_options: task_params,
        modules: File.join(__FILE__, '../../fixtures/modules')
      }
      cli.execute(options)
    end

    it "runs a powershell task passing input on stdin" do
      task_name = 'sample::winstdin'
      task_params = { 'message' => 'hi' }
      input_method = 'stdin'

      expect(executor)
        .to receive(:run_task)
        .with(%r{modules/sample/tasks/winstdin.ps1$}, input_method, task_params)
        .and_return({})
      expect(cli).to receive(:file_exist?).with(task_name).and_return(false)

      options = {
        nodes: nodes,
        mode: 'task',
        action: 'run',
        object: task_name,
        task_options: task_params,
        modules: File.join(__FILE__, '../../fixtures/modules')
      }
      cli.execute(options)
    end

    describe "file uploading" do
      it "uploads a file via scp" do
        expect(executor)
          .to receive(:file_upload)
          .with('/path/to/local', '/path/to/remote')
          .and_return({})
        expect(cli)
          .to receive(:file_exist?)
          .with('/path/to/local')
          .and_return(true)

        options = {
          nodes: nodes,
          mode: 'file',
          action: 'upload',
          object: '/path/to/local',
          leftovers: ['/path/to/remote']
        }
        cli.execute(options)
      end

      it "raises if the local file doesn't exist" do
        expect(cli)
          .to receive(:file_exist?)
          .with('/path/to/local')
          .and_return(false)

        options = {
          nodes: nodes,
          mode: 'file',
          action: 'upload',
          object: '/path/to/local',
          leftovers: ['/path/to/remote']
        }
        expect {
          cli.execute(options)
        }.to raise_error(
          Bolt::CLIError,
          %r{The source file '/path/to/local' does not exist}
        )
      end
    end
  end
end
