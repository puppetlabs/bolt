require 'spec_helper'
require 'json'
require 'bolt'
require 'bolt/node'

describe Bolt::Node do
  describe "initializing nodes from uri" do
    let(:config) { Bolt::Config.new }
    it "understands user and password" do
      node = Bolt::Node.from_uri('ssh://iuyergkj:123456@whitehouse.gov',
                                 config: config)
      expect(node.user).to eq('iuyergkj')
      expect(node.password).to eq('123456')
      expect(node.uri).to eq('ssh://iuyergkj:123456@whitehouse.gov')
    end

    it "defaults to specified user and password" do
      config[:transports][:ssh][:user] = 'somebody'
      config[:transports][:ssh][:password] = 'very secure'
      node = Bolt::Node.from_uri('ssh://localhost', config: config)
      expect(node.user).to eq('somebody')
      expect(node.password).to eq('very secure')
    end

    it "uri overrides specified user and password" do
      config[:transports][:ssh][:user] = 'somebody'
      config[:transports][:ssh][:password] = 'very secure'
      node = Bolt::Node.from_uri('ssh://toor:better@localhost', config: config)
      expect(node.user).to eq('toor')
      expect(node.password).to eq('better')
    end

    it "strips brackets from ipv6 addresses in a uri" do
      expect(Bolt::SSH).to receive(:new).with('::1', any_args)

      Bolt::Node.from_uri('ssh://[::1]:22', config: config)
    end
  end

  def mock_task_result(stdout, exit_code = 0)
    Bolt::TaskResult.new(stdout, '', exit_code)
  end

  def mock_failure(_exit_code, _stdout, _stderr = nil)
    Bolt::Result.new('kind' => 'oops')
  end

  describe "returning results from tasks" do
    it "on success converts json on stdout" do
      result = mock_task_result({ hostname: "frogstar" }.to_json)

      node = Bolt::SSH.new('localhost')
      expect(node).to receive(:_run_task).and_return(result)

      result = node.run_task('generic', 'stdin', {})
      expect(result.error).to be_nil
      expect(result.to_h)
        .to eq('value' => { 'hostname' => 'frogstar' })
    end

    it "stores stdout in _output if it cannot be parsed as json" do
      result = mock_task_result("some output")

      node = Bolt::SSH.new('localhost')
      expect(node).to receive(:_run_task).and_return(result)

      expect(node.run_task('generic', 'stdin', {}).to_h)
        .to eq('value' => { '_output' => 'some output' })
    end

    it "on failure converts json on stdout if it conforms to expectations" do
      task_output = { 'return' => 'info',
                      '_error' => { 'kind' => 'mytask/oops',
                                    'msg' => 'messed up, sorry',
                                    'details' => {} } }
      result = mock_task_result(task_output.to_json, 1)

      node = Bolt::SSH.new('localhost')
      expect(node).to receive(:_run_task).and_return(result)

      expect(node.run_task('generic', 'stdin', {}).to_h)
        .to eq('value' => { 'return' => 'info' },
               'error' => { 'kind' => 'mytask/oops',
                            'msg' => 'messed up, sorry',
                            'details' => {} })
    end

    it "on failure generates an error hash if the task does not provide one" do
      result = mock_task_result("an error occurred", 1)

      node = Bolt::SSH.new('localhost')
      expect(node).to receive(:_run_task).and_return(result)

      expect(node.run_task('generic', 'stdin', {}).to_h)
        .to eq('value' => { '_output' => 'an error occurred' },
               'error' => { 'kind' => 'puppetlabs.tasks/task-error',
                            'issue_code' => 'TASK_ERROR',
                            'msg' => 'The task failed with exit code 1',
                            'details' => { 'exit_code' => 1 } })
    end
  end

  def mock_command_result(stdout, stderr, exit_code = 0)
    Bolt::CommandResult.new(stdout, stderr, exit_code)
  end

  describe "returning results from commands" do
    it "on success returns a result with stdout, stderr, and exit_code" do
      result = mock_command_result("standard out", "less standard")
      node = Bolt::SSH.new('localhost')
      expect(node).to receive(:_run_command).and_return(result)

      expect(node.run_command('ls').to_h['value'])
        .to eq('stdout' => 'standard out',
               'stderr' => 'less standard',
               'exit_code' => 0)
    end

    it "on failure returns a result with stdout, stderr, and exit_code" do
      result = mock_command_result("standard out", "less standard", 27)
      node = Bolt::SSH.new('localhost')
      expect(node).to receive(:_run_command).and_return(result)

      expect(node.run_command('ls').to_h['value'])
        .to eq('stdout' => 'standard out',
               'stderr' => 'less standard',
               'exit_code' => 27)
    end

    it "on exception returns a result with an exception message" do
      node = Bolt::SSH.new('localhost')
      ex = RuntimeError.new('something went wrong')
      ex.set_backtrace('/path/to/bolt/node.rb:42')
      expect(node).to receive(:_run_command)
        .and_return(Bolt::Result.from_exception(ex))

      expect(node.run_command('ls').to_h)
        .to eq('error' => {
                 'kind' => 'puppetlabs.tasks/exception-error',
                 'issue_code' => 'EXCEPTION',
                 'msg' => 'something went wrong',
                 'details' => { 'class' => 'RuntimeError',
                                'stack_trace' => '/path/to/bolt/node.rb:42' }
               })
    end
  end

  describe "returning results from upload" do
    it "on success returns a result with value nil" do
      result = Bolt::Result.new
      node = Bolt::SSH.new('localhost')
      expect(node).to receive(:_upload).and_return(result)

      expect(node.upload('here', 'there').to_h).to eq(
        'value' => { '_output' => "Uploaded 'here' to 'localhost:there'" }
      )
    end
  end
end
