# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/task'
require 'bolt_spec/event_collector'
require 'bolt/executor'
require 'bolt/target'
require 'bolt/inventory'

describe "Bolt::Executor" do
  include BoltSpec::Task

  let(:analytics) { Bolt::Analytics::NoopClient.new }
  let(:executor) { Bolt::Executor.new(1, analytics).subscribe(collector) }
  let(:collector) { BoltSpec::EventCollector.new }
  let(:command) { "hostname" }
  let(:script) { '/path/to/script.sh' }
  let(:dest) { '/tmp/upload' }
  let(:task) { 'service::restart' }
  let(:task_arguments) { { 'name' => 'apache' } }
  let(:task_options) { { '_load_config' => true } }
  let(:transport) { double('holodeck', initialize_transport: nil) }
  let(:source) { '/etc/ssh/ssh_config' }
  let(:position) { ['/spooky/skeleton/', 10] }
  let(:file_lineno) { { 'file' => '/spooky/skeleton', 'line' => 10 } }

  def start_event(target)
    { type: :node_start, target: target }
  end

  def success_event(result)
    { type: :node_result, result: result }
  end

  def mock_node_results
    {
      targets[0] => Bolt::Result.new(targets[0]),
      targets[1] => Bolt::Result.new(targets[1])
    }
  end

  let(:inventory) { Bolt::Inventory.empty }
  let(:targets) { inventory.get_targets(%w[target1 target2]) }
  let(:node_results) { mock_node_results }
  let(:ssh) { executor.transport('ssh') }

  context 'running a command' do
    it 'executes on all nodes' do
      node_results.each do |target, result|
        expect(ssh).to receive(:run_command).with(target, command, {}, []).and_return(result)
      end

      executor.run_command(targets, command, {})
    end

    it 'starts and stops the spinner' do
      executor.run_command(targets, command, {})
      expect(collector.events).to include({ type: :start_spin })
      expect(collector.events).to include({ type: :stop_spin })
    end

    it 'passes run_as' do
      executor.run_as = 'foo'
      node_results.each do |target, result|
        expect(ssh).to receive(:run_command).with(target, command, { run_as: 'foo' }, [])
                                            .and_return(result)
      end

      executor.run_command(targets, command)
    end

    it "publishes an event for each result" do
      node_results.each do |target, result|
        expect(ssh).to receive(:run_command).with(target, command, {}, []).and_return(result)
      end

      executor.run_command(targets, command)
      executor.shutdown

      node_results.each do |target, result|
        expect(collector.events).to include(success_event(result))
        expect(collector.events).to include(start_event(target))
      end
    end

    it 'catches errors' do
      node_results.each_key do |target|
        error = Bolt::Error.new('failed', 'my-exception', file_lineno)
        expect(ssh).to receive(:run_command).with(target, command, {}, position)
                                            .and_raise(error)
      end

      executor.run_command(targets, command, {}, position)
      executor.shutdown

      expect(collector.results.length).to eq(node_results.length)
      collector.results.each do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
        expect(result.error_hash['details']).to include(file_lineno)
      end
    end
  end

  context 'executes running a script' do
    it "on all nodes" do
      node_results.each do |target, result|
        expect(ssh).to receive(:run_script).with(target, script, [], {}, []).and_return(result)
      end

      results = executor.run_script(targets, script, [], {})
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
      end
    end

    it 'passes run_as' do
      executor.run_as = 'foo'
      node_results.each do |target, result|
        expect(ssh).to receive(:run_script).with(target, script, [], { run_as: 'foo' }, [])
                                           .and_return(result)
      end

      results = executor.run_script(targets, script, [])
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
      end
    end

    it "yields each result" do
      node_results.each do |target, result|
        expect(ssh).to receive(:run_script).with(target, script, [], {}, []).and_return(result)
      end

      executor.run_script(targets, script, [])
      executor.shutdown

      node_results.each do |target, result|
        expect(collector.events).to include(success_event(result))
        expect(collector.events).to include(start_event(target))
      end
    end

    it 'catches errors' do
      node_results.each_key do |target|
        expect(ssh)
          .to receive(:run_script)
          .with(target, script, [], {}, position)
          .and_raise(Bolt::Error.new('failed', 'my-exception', file_lineno))
      end

      executor.run_script(targets, script, [], {}, position)
      executor.shutdown

      expect(collector.results.length).to eq(node_results.length)
      collector.results.each do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
        expect(result.error_hash['details']).to include(file_lineno)
      end
    end
  end

  context 'running a task' do
    it "executes on all nodes" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:run_task)
          .with(target, task_type(task), task_arguments, task_options, [])
          .and_return(result)
      end

      results = executor.run_task(targets, mock_task(task), task_arguments, task_options)
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
        expect(result).to be_success
      end
    end

    it 'passes _run_as' do
      executor.run_as = 'foo'
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:run_task)
          .with(target, task_type(task), task_arguments, { run_as: 'foo' }.merge(task_options), [])
          .and_return(result)
      end

      results = executor.run_task(targets, mock_task(task), task_arguments, task_options)
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
      end
    end

    it "yields each result" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:run_task)
          .with(target, task_type(task), task_arguments, task_options, [])
          .and_return(result)
      end

      executor.run_task(targets, mock_task(task), task_arguments, task_options)
      executor.shutdown

      node_results.each do |target, result|
        expect(collector.events).to include(success_event(result))
        expect(collector.events).to include(start_event(target))
      end
    end

    it 'catches errors' do
      node_results.each_key do |target|
        expect(ssh)
          .to receive(:run_task)
          .with(target, task_type(task), task_arguments, task_options, position)
          .and_raise(Bolt::Error.new('failed', 'my-exception', file_lineno))
      end

      executor.run_task(targets, mock_task(task), task_arguments, task_options, position)
      executor.shutdown

      expect(collector.results.length).to eq(node_results.length)
      collector.results.each do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
        expect(result.error_hash['details']).to include(file_lineno)
      end
    end
  end

  context 'running a task with per-target params' do
    let(:target_mapping) do
      targets.each_with_object({}) { |target, map| map[target] = { 'name' => target.name } }
    end

    it "executes on all targets" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:run_task)
          .with(target, task_type(task), target_mapping[target], task_options, [])
          .and_return(result)
      end

      results = executor.run_task_with(target_mapping, mock_task(task), task_options)
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
        expect(result).to be_success
      end
    end

    it 'passes _run_as' do
      executor.run_as = 'foo'
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:run_task)
          .with(target, task_type(task), target_mapping[target], { run_as: 'foo' }.merge(task_options), [])
          .and_return(result)
      end

      results = executor.run_task_with(target_mapping, mock_task(task), task_options)
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
      end
    end

    it "yields each result" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:run_task)
          .with(target, task_type(task), target_mapping[target], task_options, [])
          .and_return(result)
      end

      executor.run_task_with(target_mapping, mock_task(task), task_options)
      executor.shutdown

      node_results.each do |target, result|
        expect(collector.events).to include(success_event(result))
        expect(collector.events).to include(start_event(target))
      end
    end

    it 'catches errors' do
      node_results.each_key do |target|
        expect(ssh)
          .to receive(:run_task)
          .with(target, task_type(task), target_mapping[target], task_options, position)
          .and_raise(Bolt::Error.new('failed', 'my-exception', file_lineno))
      end

      executor.run_task_with(target_mapping, mock_task(task), task_options, position)
      executor.shutdown

      expect(collector.results.length).to eq(node_results.length)
      collector.results.each do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
        expect(result.error_hash['details']).to include(file_lineno)
      end
    end
  end

  context 'uploading a file' do
    it "executes on all nodes" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:upload)
          .with(target, script, dest, {})
          .and_return(result)
      end

      results = executor.upload_file(targets, script, dest)
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
      end
    end

    it "yields each result" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:upload)
          .with(target, script, dest, {})
          .and_return(result)
      end

      executor.upload_file(targets, script, dest)
      executor.shutdown

      node_results.each do |target, result|
        expect(collector.events).to include(success_event(result))
        expect(collector.events).to include(start_event(target))
      end
    end

    it 'catches errors' do
      node_results.each_key do |target|
        expect(ssh)
          .to receive(:upload)
          .with(target, script, dest, {})
          .and_raise(Bolt::Error.new('failed', 'my-exception'))
      end

      executor.upload_file(targets, script, dest)
      executor.shutdown

      expect(collector.results.length).to eq(node_results.length)
      collector.results.each do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
      end
    end
  end

  context 'downloading a file' do
    it 'creates the destination directory' do
      Dir.mktmpdir(nil, Dir.pwd) do |destination|
        allow(ssh).to receive(:download)
        expect(FileUtils).to receive(:mkdir_p).with(destination)
        expect(FileUtils).to receive(:mkdir_p).with(File.expand_path(File.join('~', '.puppetlabs', 'bolt')))

        executor.download_file(targets, source, destination)
      end
    end

    it 'executes on all nodes' do
      Dir.mktmpdir(nil, Dir.pwd) do |destination|
        node_results.each do |target, result|
          target_destination = File.expand_path(target.safe_name, destination)
          expect(ssh)
            .to receive(:download)
            .with(target, source, target_destination, {})
            .and_return(result)
        end

        results = executor.download_file(targets, source, destination)

        results.each do |result|
          expect(result).to be_instance_of(Bolt::Result)
        end
      end
    end

    it 'yields each result' do
      Dir.mktmpdir(nil, Dir.pwd) do |destination|
        node_results.each do |target, result|
          target_destination = File.expand_path(target.safe_name, destination)
          expect(ssh)
            .to receive(:download)
            .with(target, source, target_destination, {})
            .and_return(result)
        end

        executor.download_file(targets, source, destination)
        executor.shutdown

        node_results.each do |target, result|
          expect(collector.events).to include(success_event(result))
          expect(collector.events).to include(start_event(target))
        end
      end
    end

    it 'catches errors' do
      Dir.mktmpdir(nil, Dir.pwd) do |destination|
        node_results.each_key do |target|
          target_destination = File.expand_path(target.safe_name, destination)
          expect(ssh)
            .to receive(:download)
            .with(target, source, target_destination, {})
            .and_raise(Bolt::Error.new('failed', 'my-exception'))
        end

        executor.download_file(targets, source, destination)
        executor.shutdown

        expect(collector.results.length).to eq(node_results.length)
        collector.results.each do |result|
          expect(result.error_hash['msg']).to eq('failed')
          expect(result.error_hash['kind']).to eq('my-exception')
        end
      end
    end
  end

  context 'waiting until targets are available' do
    it 'waits on all nodes' do
      node_results.each do |target, _|
        expect(ssh)
          .to receive(:connected?)
          .with(target)
          .and_return(true)
      end

      results = executor.wait_until_available(targets)
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
        expect(result.action).to eq('wait_until_available')
      end
    end

    it 'errors after timeout' do
      allow(ssh).to receive(:connected?).and_return(false)

      results = executor.wait_until_available(targets, wait_time: 0, retry_interval: 0)
      results.each do |result|
        expect(result.action).to eq('wait_until_available')
        expect(result.error_hash['msg']).to eq('Timed out waiting for target')
        expect(result.error_hash['kind']).to eq('puppetlabs.tasks/exception-error')
      end
    end

    it 'errors after a short timeout' do
      allow(ssh).to receive(:connected?).and_return(false)
      expect(executor).to receive(:wait_now).and_return(Time.now - 1, Time.now, Time.now + 1)
      expect(executor).to receive(:sleep).with(1)

      results = executor.wait_until_available([targets[0]], wait_time: 2, retry_interval: 1)
      results.each do |result|
        expect(result.action).to eq('wait_until_available')
        expect(result.error_hash['msg']).to eq('Timed out waiting for target')
        expect(result.error_hash['kind']).to eq('puppetlabs.tasks/exception-error')
      end
    end

    it 'errors after default timeout' do
      allow(ssh).to receive(:connected?).and_return(false)
      expect(executor).to receive(:wait_now).and_return(Time.now - 121, Time.now)

      results = executor.wait_until_available([targets[0]])
      results.each do |result|
        expect(result.action).to eq('wait_until_available')
        expect(result.error_hash['msg']).to eq('Timed out waiting for target')
        expect(result.error_hash['kind']).to eq('puppetlabs.tasks/exception-error')
      end
    end

    context 'with batched execution with more than one target' do
      let(:pcp) { executor.transport('pcp') }
      let(:target1) { inventory.get_target('pcp://node1') }
      let(:target2) { inventory.get_target('pcp://node2') }
      let(:targets) { [target1, target2] }

      it 'partitions failures and successes by batch' do
        allow(pcp).to receive(:batch_connected?).with(targets).and_return(false)
        allow(pcp).to receive(:batch_connected?).with([target1]).and_return(false)
        allow(pcp).to receive(:batch_connected?).with([target2]).and_return(true)

        results = executor.wait_until_available(targets, wait_time: 1, retry_interval: 1)
        expect(results.error_set.targets).to include(target1)
        expect(results.ok_set.targets).to include(target2)
      end
    end
  end

  context 'prompting' do
    let(:prompt)   { 'prompt' }
    let(:response) { 'response' }

    it 'prompts for data on STDERR when executed' do
      allow($stdin).to receive(:tty?).and_return(true)
      allow($stdin).to receive(:gets).and_return(response)
      expect($stderr).to receive(:print).with("#{prompt}: ")

      executor.prompt(prompt, {})
    end

    it 'does not show input when sensitive' do
      allow($stdin).to receive(:tty?).and_return(true)
      allow($stderr).to receive(:puts)
      allow($stderr).to receive(:print).with("#{prompt}: ")
      expect($stdin).to receive(:noecho).and_return(prompt)

      executor.prompt(prompt, sensitive: true)
    end

    it 'returns the default value if no input is provided' do
      allow($stdin).to receive(:tty?).and_return(true)
      allow($stderr).to receive(:print).with("#{prompt} [#{response}]: ")
      expect($stdin).to receive(:gets).and_return('')

      result = executor.prompt(prompt, default: response)
      expect(result).to eq(response)
    end

    it 'does not display the default value when sensitive' do
      allow($stdin).to receive(:tty?).and_return(true)
      allow($stderr).to receive(:print).with("#{prompt}: ")
      allow($stdin).to receive(:noecho).and_return('')

      result = executor.prompt(prompt, default: response, sensitive: true)
      expect(result).to eq(response)
    end

    it 'errors if STDIN is not a tty' do
      allow($stdin).to receive(:tty?).and_return(false)
      expect { executor.prompt(prompt, {}) }.to raise_error(Bolt::Error, /STDIN is not a tty, unable to prompt/)
    end

    it 'returns the default value if STDIN is not a tty' do
      allow($stdin).to receive(:tty?).and_return(false)

      result = executor.prompt(prompt, default: response)
      expect(result).to eq(response)
    end
  end

  it "returns and notifies an error result" do
    node_results.each_key do |_target|
      expect(ssh)
        .to receive(:with_connection)
        .and_raise(
          Bolt::Node::ConnectError.new('Authentication failed', 'AUTH_ERROR')
        )
    end

    results = executor.run_command(targets, command)
    executor.shutdown

    results.each do |result|
      expect(result.error_hash['kind']).to eq('puppetlabs.tasks/connect-error')
      expect(result.error_hash['msg']).to eq('Authentication failed')
    end

    expect(collector.events.count).to eq(10)
    expect(results).to eq(Bolt::ResultSet.new(collector.results))
  end

  it "returns and notifies an error result for NotImplementedError" do
    node_results.each_key do |_target|
      expect(ssh)
        .to receive(:with_connection)
        .and_raise(
          NotImplementedError.new('ed25519 is not supported')
        )
    end

    results = executor.run_command(targets, command)
    executor.shutdown

    results.each do |result|
      expect(result.error_hash['kind']).to eq('puppetlabs.tasks/exception-error')
      expect(result.error_hash['msg']).to eq('ed25519 is not supported')
    end

    expect(collector.events.count).to eq(10)
    expect(results).to eq(Bolt::ResultSet.new(collector.results))
  end

  it "logs an error and does not notify if the transport incorrectly implements batch_execute" do
    node_results.each_key do |_target|
      expect(ssh)
        .to receive(:batch_command)
        .and_raise(
          NotImplementedError.new("I don't know what I'm doing")
        )
    end

    results = executor.run_command(targets, command)
    executor.shutdown

    expect(collector.results).to be_empty

    results.each do |result|
      expect(result.error_hash['kind']).to eq('puppetlabs.tasks/exception-error')
      expect(result.error_hash['msg']).to eq("I don't know what I'm doing")
    end

    logs = @log_output.readlines
    expect(logs).to include(/WARN .*I don't know what I'm doing/)
  end

  context "targets with different protocols" do
    let(:targets) {
      inventory.get_targets(['ssh://node1', 'winrm://node2', 'pcp://node3'])
    }

    it "returns ensures that every target has a result, no matter what" do
      result_set = executor.batch_execute(targets) do
        # Intentionally *don't* return a result
        []
      end

      expect(result_set.names).to eq(targets.map(&:name))
      result_set.each do |result|
        expect(result).not_to be_success
        expect(result.error_hash['msg']).to match(/No result was returned/)
      end
    end
  end

  context "with concurrency 2" do
    let(:targets) {
      inventory.get_targets(%w[node1 node2 node3])
    }

    let(:executor) { Bolt::Executor.new(2, analytics) }

    it "batch_execute only creates 2 threads" do
      value = {
        'stdout'        => 'foo',
        'stderr'        => 'bar',
        'merged_output' => "foo\nbar",
        'exit_code'     => 0
      }

      state = targets.each_with_object({}) do |target, acc|
        acc[target] = { promise: Concurrent::Promise.new { Bolt::Result.for_command(target, value) },
                        running: false }
      end

      # calling promise.value will block the thread from completing
      t = Thread.new {
        executor.batch_execute(targets) do |_transport, batch|
          target = batch[0]
          state[target][:running] = true
          result = state[target][:promise].value
          state[target][:running] = false
          result
        end
      }

      running = 0
      time = 0
      timer = Time.now

      while (time < 5) && (running != 2)
        sleep(0.1)
        running = state.reduce(0) do |acc, (_k, v)|
          acc += 1 if v[:running]
          acc
        end
        time = Time.now - timer
      end

      expect(running).to eq(2)
      # execute all the promises to release the threads
      state.each_key { |k| state[k][:promise].execute }
      t.join
    end
  end

  context "with concurrency 0" do
    let(:targets) {
      inventory.get_targets(%w[node1 node2])
    }

    let(:executor) { Bolt::Executor.new(0) }

    it "batch_execute runs sequentially" do
      targs = []
      executor.batch_execute(targets) do |_transport, batch|
        targs.concat(batch)
      end

      expect(targs).to eq(targets)
    end
  end

  it "returns an exception result if the connect raises an unhandled error" do
    node_results.each_key do |_target|
      expect(ssh).to receive(:with_connection).and_raise("reset")
    end

    results = executor.run_command(targets, command)
    results.each do |result|
      expect(result.error_hash['kind']).to eq('puppetlabs.tasks/exception-error')
    end
  end

  context 'with modified default concurrency' do
    let(:executor) { Bolt::Executor.new(2, analytics, false, true).subscribe(collector) }
    let(:collector) { BoltSpec::EventCollector.new }

    it "doesn't warn if concurrency limit isn't reached" do
      executor.run_command(targets, command, {})
      expect(@log_output.readlines).not_to include(/The ulimit is low, which might cause file limit issues/)
    end

    it 'warns if concurrency limit is reached' do
      targets = inventory.get_targets(%w[target1 target2 target3])
      executor.run_command(targets, command, {})
      expect(@log_output.readlines).to include(/The ulimit is low, which might cause file limit issues/)
    end

    it 'only warns once' do
      targets = inventory.get_targets(%w[target1 target2 target3])
      executor.run_command(targets, command, {})
      expect(@log_output.readlines).to include(/The ulimit is low, which might cause file limit issues/)

      executor.run_command(targets, command, {})
      expect(@log_output.readlines).not_to include(/The ulimit is low, which might cause file limit issues/)
    end
  end

  context 'reporting analytics data' do
    let(:targets) {
      inventory.get_targets(['ssh://node1', 'ssh://node2', 'winrm://node3', 'pcp://node4'])
    }

    it 'reports one event for each transport used' do
      expect(analytics).to receive(:event).with('Transport', 'initialize', label: 'ssh', value: 2).once
      expect(analytics).to receive(:event).with('Transport', 'initialize', label: 'winrm', value: 1).once
      expect(analytics).to receive(:event).with('Transport', 'initialize', label: 'orch', value: 1).once

      executor.batch_execute(targets) {}
      executor.batch_execute(targets) {}
    end

    context "#report_function_call" do
      it 'reports an event for the given function' do
        expect(analytics).to receive(:event).with('Plan', 'call_function', label: 'add_facts')

        executor.report_function_call('add_facts')
      end
    end

    context "#report_bundled_content" do
      let(:executor) { Bolt::Executor.new(2, analytics) }

      before :each do
        analytics.bundled_content = %w[canary facts]
      end

      it 'reports an event when bundled plan is used' do
        expect(analytics).to receive(:report_bundled_content).with('Plan', 'canary')

        executor.report_bundled_content('Plan', 'canary')
      end

      it 'reports an event when bundled task is used' do
        expect(analytics).to receive(:report_bundled_content).with('Task', 'facts')

        executor.report_bundled_content('Task', 'facts')
      end
    end

    context "#report_file_source" do
      let(:executor) { Bolt::Executor.new(2, analytics) }

      it 'reports when a file path is absolute' do
        expect(analytics).to receive(:event).with('Plan', 'run_script', label: 'absolute')

        executor.report_file_source('run_script', '/foo/bar')
      end

      it 'reports when a file path is module' do
        expect(analytics).to receive(:event).with('Plan', 'run_script', label: 'module')

        executor.report_file_source('run_script', 'my_module/my_file')
      end
    end
  end

  context "When running a plan" do
    let(:nodes_string) { results.map(&:first).map(&:uri) }
    let(:plan_context) { { name: 'foo' } }

    before :all do
      @log_output.level = :info
    end
    after :all do
      @log_output.level = :all
    end

    it "sends event for commands" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:run_command)
          .with(target, command, {}, [])
          .and_return(result)
      end

      executor.start_plan(plan_context)
      executor.run_command(targets, command)
      executor.shutdown

      expect(collector.events).to include(include(type: :step_start, description: match(/command/)))
      expect(collector.events).to include(include(type: :step_finish, description: match(/command/)))
    end

    it "sends event for scripts" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:run_script)
          .with(target, script, [], {}, [])
          .and_return(result)
      end

      executor.start_plan(plan_context)
      executor.run_script(targets, script, [])
      executor.shutdown

      expect(collector.events).to include(include(type: :step_start, description: match(/script/)))
      expect(collector.events).to include(include(type: :step_finish, description: match(/script/)))
    end

    it "sends event for tasks" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:run_task)
          .with(target, task_type(task), task_arguments, task_options, [])
          .and_return(result)
      end

      executor.start_plan(plan_context)
      executor.run_task(targets, mock_task(task), task_arguments, task_options)
      executor.shutdown

      expect(collector.events).to include(include(type: :step_start, description: match(/task service::restart/)))
      expect(collector.events).to include(include(type: :step_finish, description: match(/task service::restart/)))
    end

    it "sends event for tasks with per-target params" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:run_task)
          .with(target, task_type(task), task_arguments, task_options, [])
          .and_return(result)
      end

      target_mapping = targets.each_with_object({}) { |target, map| map[target] = task_arguments }

      executor.start_plan(plan_context)
      executor.run_task_with(target_mapping, mock_task(task), task_options)
      executor.shutdown

      expect(collector.events).to include(include(type: :step_start, description: match(/task service::restart/)))
      expect(collector.events).to include(include(type: :step_finish, description: match(/task service::restart/)))
    end

    it "logs uploads" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:upload)
          .with(target, script, dest, {})
          .and_return(result)
      end

      executor.start_plan(plan_context)
      executor.upload_file(targets, script, dest)
      executor.shutdown

      expect(collector.events).to include(include(type: :step_start, description: match(/file upload/)))
      expect(collector.events).to include(include(type: :step_finish, description: match(/file upload/)))
    end

    it "logs downloads" do
      Dir.mktmpdir(nil, Dir.pwd) do |destination|
        node_results.each do |target, result|
          target_destination = File.expand_path(target.safe_name, destination)
          expect(ssh)
            .to receive(:download)
            .with(target, script, target_destination, {})
            .and_return(result)
        end

        executor.start_plan(plan_context)
        executor.download_file(targets, script, destination)
        executor.shutdown

        expect(collector.events).to include(include(type: :step_start, description: match(/file download/)))
        expect(collector.events).to include(include(type: :step_finish, description: match(/file download/)))
      end
    end
  end
end
