# frozen_string_literal: true

require 'spec_helper'
require 'bolt/inventory'
require 'bolt/shell/bash'

describe Bolt::Shell::Bash do
  let(:inventory) { Bolt::Inventory.empty }
  let(:target) { inventory.get_target('foo.example.com') }
  let(:connection) { double('connection', user: 'root', reset_cwd?: true) }
  let(:shell) { Bolt::Shell::Bash.new(target, connection) }
  let(:status) { double('status', alive: false?, value: 0) }

  def mock_result(stdout: "", stderr: "", exitcode: 0, read_stdin: false)
    in_r, in_w = IO.pipe
    out_r, out_w = IO.pipe
    err_r, err_w = IO.pipe
    th = Thread.new do
      out_w.write(stdout)
      err_w.write(stderr)
      out_w.close
      err_w.close
      in_r.read if read_stdin
      exitcode
    end
    [in_w, out_r, err_r, th]
  end

  def echo_result
    in_r, in_w = IO.pipe
    out_r, out_w = IO.pipe
    err_r, err_w = IO.pipe
    th = Thread.new do
      input = StringIO.new
      input << in_r.read
      out_w.write(input.string)
      out_w.close
      err_w.close
      0
    end
    [in_w, out_r, err_r, th]
  end

  before :each do
    allow(connection).to receive(:execute).and_return(mock_result)
  end

  it "provides the 'shell' feature" do
    expect(shell.provided_features).to eq(['shell'])
  end

  describe "#running_as" do
    it "overrides run_as set on the target and resets it afterward" do
      inventory.set_config(target, target.transport, 'run-as' => 'soandso')
      expect(shell.run_as).to eq('soandso')
      shell.running_as('suchandsuch') do
        expect(shell.run_as).to eq('suchandsuch')
      end
      expect(shell.run_as).to eq('soandso')
    end
  end

  describe "#handle_sudo" do
    let(:stdin) { StringIO.new }

    describe "when sudo prompt is present" do
      it "writes the sudo password to stdin" do
        inventory.set_config(target, target.transport, 'sudo-password' => 'my-password')
        result = shell.handle_sudo(stdin, shell.sudo_prompt, "")
        expect(result).to be_empty
        expect(stdin.string).to eq("my-password\n")
      end

      it "uses password as the default sudo-password" do
        inventory.set_config(target, target.transport, 'password' => 'my-password')
        result = shell.handle_sudo(stdin, shell.sudo_prompt, "")
        expect(result).to be_empty
        expect(stdin.string).to eq("my-password\n")
      end

      it "fails if no sudo password is set" do
        err = /Sudo password.*was not provided/
        expect { shell.handle_sudo(stdin, shell.sudo_prompt, "") }.to raise_error(Bolt::Node::EscalateError, err)
      end
    end

    it "writes stdin if the sudo id is encountered" do
      uuid = SecureRandom.uuid
      allow(SecureRandom).to receive(:uuid).and_return(uuid)

      result = shell.handle_sudo(stdin, uuid, "hello world")
      expect(result).to be_empty
      expect(stdin.string).to eq("hello world\n")
    end

    it "raises an error if the user is not in sudoers" do
      msg = "root is not in the sudoers file."
      err = /User root does not have sudo permission/
      expect { shell.handle_sudo(stdin, msg, "") }.to raise_error(Bolt::Node::EscalateError, err)
    end

    it "raises an error if the password is wrong" do
      msg = "Sorry, try again."
      err = /Sudo password for user root not recognized/
      expect { shell.handle_sudo(stdin, msg, "") }.to raise_error(Bolt::Node::EscalateError, err)
    end

    it "returns the input string if there's no error" do
      line = "This is just ordinary output"
      expect(shell.handle_sudo(stdin, line, "")).to eq(line)
    end
  end

  describe "#run_command" do
    it "runs a command" do
      expect(connection).to receive(:execute).with('echo hello world')
      shell.run_command('echo hello world')
    end

    it "runs a command as the run-as user set on the target" do
      inventory.set_config(target, target.transport, 'run-as' => 'soandso')
      expect(connection).to receive(:execute).with(/sudo .* -u soandso .* whoami/)
      shell.run_command('whoami')
    end

    it "runs a command as the run-as user passed as an option" do
      inventory.set_config(target, 'ssh', 'run-as' => 'soandso')
      expect(connection).to receive(:execute).with(/sudo .* -u suchandsuch .* whoami/)

      shell.run_command('whoami', run_as: 'suchandsuch')
    end

    it "sets environment variables if requested" do
      expect(connection).to receive(:execute).with('FOO=bar sh -c echo\\ \\$FOO')

      shell.run_command('echo $FOO', env_vars: { 'FOO' => 'bar' })
    end
  end

  describe "#execute" do
    it "returns stdout, stderr and exitcode" do
      execute_result = mock_result(stdout: "hello world", stderr: "some errors", exitcode: 6)
      expect(connection).to receive(:execute).and_return(execute_result)

      result = shell.execute('my cool command')
      expect(result.stdout.string).to eq("hello world")
      expect(result.stderr.string).to eq("some errors")
      expect(result.exit_code).to eq(6)
    end

    it "runs a command with extremely long UTF-8 output" do
      stdout = "hello ☃" * 60000
      execute_result = mock_result(stdout: stdout)
      expect(connection).to receive(:execute).and_return(execute_result)

      result = shell.execute('my cool command')
      expect(result.stdout.string).to eq(stdout)
    end

    it "passes stdin content to the command" do
      expect(connection).to receive(:execute).and_return(echo_result)

      result = shell.execute('something', stdin: "hello world")
      expect(result.stdout.string).to eq("hello world")
    end

    it "runs a command with extremely long UTF-8 input" do
      stdin = "hello ☃" * 60000
      expect(connection).to receive(:execute).and_return(echo_result)

      result = shell.execute('something', stdin: stdin)
      expect(result.stdout.string).to eq(stdin)
    end

    it "runs with the specified interpreter" do
      expect(connection).to receive(:execute).with('/path/to/my/ruby /path/to/my/script.rb')
      shell.execute('/path/to/my/script.rb', interpreter: "/path/to/my/ruby")
    end

    it "appends noexec message when exit code is 126" do
      execute_result = mock_result(stdout: "", stderr: "Permission denied", exitcode: 126)
      expect(connection).to receive(:execute).and_return(execute_result)

      result = shell.execute('my cool command')
      expect(result.stderr.string).to include("This might be caused by the default tmpdir being mounted")
    end
  end

  describe "when using run-as" do
    it "uses an alternate sudo-executable" do
      inventory.set_config(target, 'ssh', 'run-as' => 'soandso', 'sudo-executable' => 'mysudo')
      expect(connection).to receive(:execute).with(/mysudo .* -u soandso .* whoami/)

      shell.run_command('whoami')
    end

    it "uses a run-as-comand" do
      inventory.set_config(target, 'ssh', 'run-as' => 'soandso', 'run-as-command' => %w[my run-as command])
      expect(connection).to receive(:execute).with(/my run-as command soandso .* whoami/)

      shell.run_command('whoami')
    end
  end
end
