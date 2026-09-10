# frozen_string_literal: true

require 'spec_helper'
require 'bolt/outputter'
require 'bolt/cli'
require 'bolt/plan_result'
require 'bolt/apply_result'
require 'bolt/error'

describe "Bolt::Outputter::Human" do
  let(:output) { StringIO.new }
  let(:outputter) { Bolt::Outputter::Human.new(false, false, false, false, output) }
  let(:inventory) { Bolt::Inventory.empty }
  let(:target) { inventory.get_target('target1') }
  let(:target2) { inventory.get_target('target2') }
  let(:results) {
    Bolt::ResultSet.new(
      [
        Bolt::Result.new(target, message: "ok", action: 'action'),
        Bolt::Result.new(target2, error: { 'msg' => 'oops' }, action: 'action')
      ]
    )
  }

  it "starts items in head" do
    outputter.print_head
    expect(output.string).to eq('')
  end

  it "allows empty items" do
    outputter.print_head
    outputter.print_summary(Bolt::ResultSet.new([]), 2.0)
    expect(output.string).to eq("Ran on 0 targets in 2.0 sec\n")
  end

  it "prints status" do
    outputter.print_head
    results.each do |result|
      outputter.print_result(result)
    end
    expect(outputter).to receive(:colorize).with(:red, 'Failed on 1 target: target2').and_call_original
    outputter.print_summary(results, 10.0)
    lines = output.string
    expect(lines).to match(/Finished on target1/)
    expect(lines).to match(/Failed on target2/)
    expect(lines).to match(/oops/)
    summary = lines.split("\n")[-3..-1]
    expect(summary[0]).to eq('Successful on 1 target: target1')
    expect(summary[1]).to eq('Failed on 1 target: target2')
    expect(summary[2]).to eq('Ran on 2 targets in 10.0 sec')
  end

  context 'with multiple successes' do
    let(:results) {
      Bolt::ResultSet.new(
        [
          Bolt::Result.new(target, message: 'ok'),
          Bolt::Result.new(target2, message: 'also ok')
        ]
      )
    }

    it 'prints success, omits failure' do
      outputter.print_summary(results, 0.0)
      summary = output.string.split("\n")
      expect(summary[0]).to eq('Successful on 2 targets: target1,target2')
      expect(summary[1]).to eq('Ran on 2 targets in 0.0 sec')
    end
  end

  context 'with multiple failures' do
    let(:results) {
      Bolt::ResultSet.new(
        [
          Bolt::Result.new(target, error: { 'msg' => 'oops' }),
          Bolt::Result.new(target2, error: { 'msg' => 'also oops' })
        ]
      )
    }

    it 'prints success, omits failure' do
      outputter.print_summary(results, 0.0)
      summary = output.string.split("\n")
      expect(summary[0]).to eq('Failed on 2 targets: target1,target2')
      expect(summary[1]).to eq('Ran on 2 targets in 0.0 sec')
    end
  end

  it "formats a table" do
    output = outputter.format_table([%w[a b], %w[c1 d]])
    expect(output.to_s).to eq(<<~TABLE.chomp)
      a    b
      c1   d
    TABLE
  end

  it 'formats a modules with padding' do
    modules = { "/modulepath" =>
                [{ name: "boltlib", version: nil, internal_module_group: "Plan Language Modules" },
                 { name: "ctrl", version: nil, internal_module_group: "Plan Language Modules" },
                 { name: "dir", version: nil, internal_module_group: "Plan Language Modules" }] }
    command = Bolt::Util.powershell? ? 'Get-BoltModule -Name <MODULE>' : 'bolt module show <MODULE>'
    outputter.print_module_list(modules)
    expect(output.string).to match(<<~TABLE)
    Plan Language Modules
      boltlib   (built-in)
      ctrl      (built-in)
      dir       (built-in)

    Additional information
      Use '#{command}' to view details for a specific module.
    TABLE
  end

  it "formats a task" do
    name = 'cinnamon_roll'
    files = [{ 'name' => 'cinnamon.rb',
               'path' => '/path/to/cinnamony/goodness/tasks/cinnamon.rb' },
             { 'name' => 'roll.sh',
               'path' => '/path/to/wrong/module/tasks/roll.sh' }]
    metadata = {
      'description' => 'A delicious sweet bun',
      'parameters' => {
        'icing' => {
          'type' => 'Cream cheese',
          'description' => 'Rich, tangy, sweet'
        }
      }
    }

    command = if Bolt::Util.powershell?
                'Invoke-BoltTask -Name cinnamon_roll -Targets <targets> icing=<value>'
              else
                'bolt task run cinnamon_roll --targets <targets> icing=<value>'
              end

    outputter.print_task_info(task: Bolt::Task.new(name, metadata, files))
    expect(output.string).to match(/cinnamon_roll.*A delicious sweet bun/m),
                             'Does not print name and description'
    expect(output.string).to match(/Usage.*#{Regexp.escape(command)}/m),
                             'Does not print usage string'
    expect(output.string).to match(/Parameters.*icing.*Cream cheese/m),
                             'Does not print parameters'
    expect(output.string).to match(%r{Module.*/path/to/cinnamony/goodness}m),
                             'Does not print module path'
  end

  it 'succeeds if task parameters do not have a type' do
    name = 'donut'
    files = [{ 'name' => 'glazed.rb',
               'path' => '/path/to/glazed.rb' }]
    metadata = {
      'parameters' => {
        'flavor' => {
          'description' => 'What flavor of donut'
        }
      }
    }

    outputter.print_task_info(task: Bolt::Task.new(name, metadata, files))
    expect(output.string).to match(/flavor.*Any/)
  end

  it 'prints noop option in the usage if task supports noop' do
    name = 'test'
    files = [{
      'name' => 'test.rb',
      'path' => '/path/to/test.rb'
    }]
    metadata = {
      'description' => 'A test task',
      'supports_noop' => true
    }

    option = (Bolt::Util.powershell? ? '[-Noop]' : '[--noop]')

    outputter.print_task_info(task: Bolt::Task.new(name, metadata, files))
    expect(output.string).to match(Regexp.escape(option))
  end

  it 'prints modulepath as builtin for builtin modules' do
    name = 'monkey_bread'
    files = [{ 'name' => 'monkey_bread.rb',
               'path' => "#{Bolt::Config::Modulepath::MODULES_PATH}/monkey/bread" }]
    metadata = {}

    outputter.print_task_info(task: Bolt::Task.new(name, metadata, files))
    expect(output.string).to match(/Module.*built-in module/m)
  end

  it 'prints correct file separator for modulepath' do
    task = {
      'name' => 'monkey_bread',
      'files' => [{ 'name' => 'monkey_bread.rb',
                    'path' => "#{Bolt::Config::Modulepath::MODULES_PATH}/monkey/bread" }],
      'metadata' => {}
    }
    outputter.print_tasks(tasks: [task], modulepath: %w[path1 path2])
    expect(output.string).to include("path1#{File::PATH_SEPARATOR}path2")
  end

  it "formats a plan" do
    plan = {
      'name' => 'planity_plan',
      'module' => 'plans/plans/plans/plans',
      'parameters' => {
        'foo' => {
          'type' => 'Bar'
        },
        'baz' => {
          'type' => 'Bar',
          'default_value' => nil
        }
      }
    }

    command = if Bolt::Util.powershell?
                'Invoke-BoltPlan -Name planity_plan [baz=<value>] foo=<value>'
              else
                'bolt plan run planity_plan [baz=<value>] foo=<value>'
              end

    outputter.print_plan_info(plan)

    expect(output.string).to match(/planity_plan.*No description/m),
                             'Does not print plan name and description'
    expect(output.string).to match(/Usage.*#{Regexp.escape(command)}/m),
                             'Does not print usage string'
    expect(output.string).to match(/Parameters.*baz.*Bar.*foo.*Bar/m),
                             'Does not print parameters'
    expect(output.string).to match(%r{Module.*plans/plans/plans/plans}m),
                             'Does not print module path'
  end

  it "prints CommandResults" do
    value = {
      'stdout'        => 'stdout',
      'stderr'        => 'stderr',
      'merged_output' => "stdout\nstderr",
      'exit_code'     => 2
    }

    outputter.print_result(Bolt::Result.for_command(target, value, 'command', "executed", []))
    expect(output.string).to match(/stdout.*stderr/m)
  end

  it "prints TaskResults" do
    result = { 'key' => 'val',
               '_error' => { 'msg' => 'oops' },
               '_output' => 'hello' }
    outputter.print_result(Bolt::Result.for_task(target, result.to_json, "", 2, 'atask', []))
    lines = output.string
    expect(lines).to match(/^  oops\n  hello$/)
    expect(lines).to match(/^    "key": "val"$/)
  end

  it 'prints lookup results' do
    result = Bolt::Result.for_lookup(target, 'key', 'value')
    outputter.print_result(result)
    expect(output.string).to match(/Finished on #{target}.*value/m)
  end

  it "doesn't stacktrace when merged_output is nil" do
    value = {
      'stdout'        => 'stdout',
      'stderr'        => 'stderr',
      'merged_output' => nil,
      'exit_code'     => 2
    }
    expect {
      outputter.print_result(Bolt::Result.for_command(target, value, 'command', "executed", []))
    }.not_to raise_error
    expect(output.string).to match(/stdout.*stderr/m)
  end

  it "prints empty results from a plan" do
    outputter.print_plan_result(Bolt::PlanResult.new([], 'success'))
    expect(output.string).to eq("[]\n")
  end

  it "formats unwrapped ExecutionResult from a plan" do
    result = [
      { 'target' => 'target1', 'status' => 'finished', 'result' => { '_output' => 'yes' } },
      { 'target' => 'target2', 'status' => 'failed', 'result' =>
        { '_error' => { 'message' => 'The command failed with exit code 2',
                        'kind' => 'puppetlabs.tasks/command-error',
                        'issue_code' => 'COMMAND_ERROR',
                        'partial_result' => { 'stdout' => 'no', 'stderr' => '', 'exit_code' => 2 },
                        'details' => { 'exit_code' => 2 } } } }
    ]
    outputter.print_plan_result(Bolt::PlanResult.new(result, 'failure'))

    result_hash = JSON.parse(output.string)
    expect(result_hash).to eq(result)
  end

  it "formats hash results from a plan" do
    result = { 'some' => 'data' }
    outputter.print_plan_result(Bolt::PlanResult.new(result, 'success'))
    expect(JSON.parse(output.string)).to eq(result)
  end

  it "prints simple output from a plan" do
    result = "some data"
    outputter.print_plan_result(Bolt::PlanResult.new(result, 'success'))
    expect(output.string.strip).to eq("\"#{result}\"")
  end

  it "prints a message when a plan returns undef" do
    outputter.print_plan_result(Bolt::PlanResult.new(nil, 'success'))
    expect(output.string.strip).to eq("Plan completed successfully with no result")
  end

  it "prints the result of installing a Puppetfile successfully" do
    outputter.print_puppetfile_result(true, '/path/to/Puppetfile', '/path/to/modules')
    expect(output.string.strip).to eq("Successfully synced modules from /path/to/Puppetfile to /path/to/modules")
  end

  it "prints the result of installing a Puppetfile with a failure" do
    outputter.print_puppetfile_result(false, '/path/to/Puppetfile', '/path/to/modules')
    expect(output.string.strip).to eq("Failed to sync modules from /path/to/Puppetfile to /path/to/modules")
  end

  it "handles fatal errors" do
    outputter.fatal_error(Bolt::CLIError.new("oops"))
    expect(output.string).to eq("oops\n")
  end

  it "handles message events" do
    outputter.handle_event(type: :message, message: "hello world")
    expect(output.string).to eq("hello world\n")
  end

  it "handles nested default_output commands" do
    outputter.instance_variable_set(:@plan_depth, 1)
    outputter.handle_event(type: :disable_default_output)
    outputter.handle_event(type: :disable_default_output)
    outputter.handle_event(type: :enable_default_output)
    outputter.handle_event(type: :step_start, description: "step", targets: [target])
    expect(output.string).to eq("")
  end

  it "prints messages when default_output is disabled" do
    outputter.instance_variable_set(:@plan_depth, 1)
    outputter.handle_event(type: :disable_default_output)
    outputter.handle_event(type: :message, message: "hello!")
    expect(output.string).to eq("hello!\n")
  end

  context '#duration_to_string' do
    it 'includes only seconds when the duration is less than a minute' do
      str = outputter.duration_to_string(34)
      expect(str).to eq("34 sec")
    end

    it 'includes up to two decimal places if the duration is less than a minute' do
      str = outputter.duration_to_string(34.5678)
      expect(str).to eq("34.57 sec")
    end

    it 'includes minutes when the duration is more than a minute' do
      str = outputter.duration_to_string(99)
      expect(str).to eq("1 min, 39 sec")
    end

    it 'rounds to the nearest whole second if the duration is more than a minute' do
      str = outputter.duration_to_string(99.99)
      expect(str).to eq("1 min, 40 sec")
    end

    it 'includes hours when the duration is more than an hour' do
      str = outputter.duration_to_string(3750)
      expect(str).to eq("1 hr, 2 min, 30 sec")
    end
  end

  it 'prints a list of guide topics' do
    outputter.print_topics(topics: %w[apple banana carrot])
    expect(output.string).to eq(<<~OUTPUT)
      Topics
        apple
        banana
        carrot

      Additional information
        Use 'bolt guide <TOPIC>' to view a specific guide.
    OUTPUT
  end

  it 'prints a guide' do
    topic = 'boltymcboltface'
    guide = "The trials and tribulations of Bolty McBoltface\n"
    outputter.print_guide(guide: guide, topic: topic)
    expect(output.string).to eq("#{topic}\n  #{guide}")
  end

  it 'prints a plan-hierarchy lookup result' do
    value = 'peanut butter'
    outputter.print_plan_lookup(value)
    expect(output.string.strip).to eq(value)
  end

  it 'does not spin when spinner is set to false' do
    outputter.start_spin
    sleep(0.3)
    expect(output.string).not_to include("\b\\\b|")
    outputter.stop_spin
  end

  context 'with spinner enabled' do
    let(:outputter) { Bolt::Outputter::Human.new(false, false, false, true, output) }

    it 'spins while executing with a block' do
      expect(output).to receive(:isatty).twice.and_return(true)
      outputter.spin do
        sleep(0.3)
        expect(output.string).to include("\\\b|\b")
      end
    end

    it 'spins between start and stop' do
      expect(output).to receive(:isatty).twice.and_return(true)
      outputter.start_spin
      sleep(0.3)
      expect(output.string).to include("\\\b|\b")
      outputter.stop_spin
    end

    it 'does not spin when stdout is not a TTY' do
      expect(output).to receive(:isatty).twice.and_return(false)
      outputter.start_spin
      sleep(0.3)
      expect(output.string).not_to include("\b\\\b|")
      outputter.stop_spin
    end
  end

  context 'targets' do
    let(:inventoryfile) { '/path/to/inventory' }
    let(:target)        { { 'name' => 'target' } }

    let(:data) do
      {
        adhoc: {
          count: 1,
          targets: [target]
        },
        inventory: {
          count: 1,
          targets: [target],
          file: inventoryfile,
          default: inventoryfile
        },
        targets: [target, target],
        count: 2,
        flag: true
      }
    end

    context '#print_targets' do
      it 'prints adhoc targets' do
        outputter.print_targets(**data)
        expect(output.string).to match(/target\s*\(Not found in inventory file\)/)
      end

      it 'prints the inventory source' do
        outputter.print_targets(**data)
        expect(output.string).to match(/Inventory source.*#{inventoryfile}/m)
      end

      it 'prints a message that the inventory file does not exist' do
        data[:inventory][:file] = nil
        outputter.print_targets(**data)
        expect(output.string).to match(/Inventory source.*does not exist/m)
      end

      it 'prints target counts' do
        outputter.print_targets(**data)
        expect(output.string).to match(/2 total, 1 from inventory, 1 adhoc/)
      end

      it 'prints suggestion to use a targeting option if one was not provided' do
        data[:flag] = false
        outputter.print_targets(**data)
        expect(output.string).to match(/Use the .* option to view specific targets/)
      end

      it 'does not print suggestion to use a targeting option if one was provided' do
        outputter.print_targets(**data)
        expect(output.string).not_to match(/Use the .* option to view specific targets/)
      end

      it 'prints suggestion to use detail option' do
        outputter.print_targets(**data)
        expect(output.string).to match(/Use the .* option to view target configuration and data/)
      end
    end

    context '#print_target_info' do
      it 'prints suggestion to use a targeting option if one was not provided' do
        data[:flag] = false
        outputter.print_target_info(**data)
        expect(output.string).to match(/Use the .* option to view specific targets/)
      end

      it 'does not print suggestion to use a targeting option if one was provided' do
        outputter.print_target_info(**data)
        expect(output.string).not_to match(/Use the .* option to view specific targets/)
      end

      it 'does not print suggestion to use detail option' do
        outputter.print_target_info(**data)
        expect(output.string).not_to match(/Use the .* option to view target configuration and data/)
      end
    end
  end

  context '#print_groups' do
    let(:inventoryfile) { '/path/to/inventory' }
    let(:groups)        { %w[apple banana carrot] }

    let(:data) do
      {
        groups:    groups,
        inventory: {
          source:  inventoryfile,
          default: inventoryfile
        },
        count:     groups.count
      }
    end

    it 'prints groups' do
      outputter.print_groups(**data)
      expect(output.string).to match(/Groups.*apple.*banana.*carrot/m)
    end

    it 'prints the inventory source' do
      outputter.print_groups(**data)
      expect(output.string).to match(/Inventory source.*#{inventoryfile}/m)
    end

    it 'prints that the inventory file does not exist' do
      data[:inventory][:source] = nil
      outputter.print_groups(**data)
      expect(output.string).to match(/Inventory source.*but the file does not exist/m)
    end

    it 'prints the group count' do
      outputter.print_groups(**data)
      expect(output.string).to match(/Group count.*3 total/m)
    end
  end

  context '#print_plugin_list' do
    let(:modulepath) { ['path/to/module', 'other/path/to/module'] }

    let(:plugins) do
      {
        puppet_library: {
          'task' => 'Install the Puppet agent package by running a custom task as a plugin'
        },
        resolve_reference: {
          'custom_plugin' => 'My custom plugin',
          'quiet_plugin'  => nil
        }
      }
    end

    it 'prints a list of plugins' do
      outputter.print_plugin_list(plugins: plugins, modulepath: modulepath)

      expect(output.string).to match(/puppet_library.*resolve_reference/m),
                               'Does not print hook names'
      expect(output.string).to match(/task.*custom_plugin.*quiet_plugin/m),
                               'Does not print plugin names'
      expect(output.string).to match(/My custom plugin/),
                               'Does not print descriptions'
      expect(output.string).to match(/Install the Puppet agent package.*\.\.\./),
                               'Does not truncate descriptions'
      expect(output.string).to match(/Modulepath.*#{modulepath.join(File::PATH_SEPARATOR)}/m),
                               'Does not print modulepath'
    end
  end

  context 'string helpers' do
    describe '#wrap' do
      it 'wraps a long string at whitespace boundaries' do
        str = 'word ' * 20
        expect(outputter.wrap(str, 10)).to include("\n")
      end

      it 'returns non-strings unchanged' do
        expect(outputter.wrap(42, 10)).to eq(42)
      end
    end

    describe '#truncate' do
      it 'truncates strings longer than the width with an ellipsis' do
        str = 'longword ' * 10
        result = outputter.truncate(str, 20)
        expect(result).to end_with('...')
      end

      it 'returns strings shorter than the width unchanged' do
        expect(outputter.truncate('short', 80)).to eq('short')
      end

      it 'returns non-strings unchanged' do
        expect(outputter.truncate(42, 10)).to eq(42)
      end
    end

    describe '#remove_trail' do
      it 'removes a trailing space character' do
        expect(outputter.remove_trail("hello ")).to eq("hello")
      end

      it 'removes a trailing newline' do
        expect(outputter.remove_trail("hello\n")).to eq("hello")
      end

      it 'does not remove non-trailing whitespace' do
        expect(outputter.remove_trail("hello world")).to eq("hello world")
      end
    end
  end

  context 'with color enabled' do
    let(:outputter) { Bolt::Outputter::Human.new(true, false, false, false, output) }

    it 'colorizes output when stream is a TTY' do
      allow(output).to receive(:isatty).and_return(true)
      expect(outputter.colorize(:red, 'hello')).to match(/\033\[31m/)
    end

    it 'does not colorize output when stream is not a TTY' do
      allow(output).to receive(:isatty).and_return(false)
      expect(outputter.colorize(:red, 'hello')).to eq('hello')
    end
  end

  context 'with verbose enabled' do
    let(:outputter) { Bolt::Outputter::Human.new(false, true, false, false, output) }

    it 'prints node_start events' do
      outputter.handle_event(type: :node_start, target: target)
      expect(output.string).to match(/Started on target1/)
    end

    it 'prints node_result events' do
      result = Bolt::Result.new(target, message: 'ok', action: 'task')
      outputter.handle_event(type: :node_result, result: result)
      expect(output.string).to match(/Finished on target1/)
    end

    it 'prints verbose message events' do
      outputter.handle_event(type: :verbose, message: 'verbose info')
      expect(output.string).to match(/verbose info/)
    end

    it 'prints warn-level ApplyResult resource logs, omits info/debug' do
      report = {
        'logs' => [
          { 'level' => 'warn', 'message' => 'disk full', 'source' => 'File[/tmp/x]' },
          { 'level' => 'info', 'message' => 'skipped',   'source' => 'Puppet' }
        ]
      }
      apply_result = Bolt::ApplyResult.new(target, report: report)
      outputter.print_result(apply_result)
      expect(output.string).to match(/Warn: File\[\/tmp\/x\]: disk full/)
      expect(output.string).not_to match(/skipped/)
    end
  end

  it 'does not print verbose message events when verbose is false' do
    outputter.handle_event(type: :verbose, message: 'quiet please')
    expect(output.string).to be_empty
  end

  describe '#format_log' do
    it 'formats a warn log' do
      log = { 'level' => 'warn', 'message' => 'something wrong', 'source' => nil }
      expect(outputter.format_log(log)).to match(/Warn: something wrong/)
    end

    it 'formats an err log with a source' do
      log = { 'level' => 'err', 'message' => 'bad error', 'source' => 'MyClass' }
      expect(outputter.format_log(log)).to match(/Err: MyClass: bad error/)
    end

    it 'omits the source separator when source is nil' do
      log = { 'level' => 'warn', 'message' => 'no source', 'source' => nil }
      expect(outputter.format_log(log)).not_to match(/nil:/)
    end
  end

  context 'plan step events' do
    before(:each) { outputter.instance_variable_set(:@plan_depth, 1) }

    it 'prints step_start with target names for 5 or fewer targets' do
      outputter.handle_event(type: :step_start, description: 'run task', targets: [target, target2])
      expect(output.string).to match(/Starting: run task on target1, target2/)
    end

    it 'prints step_start with a count for more than 5 targets' do
      many = (1..6).map { |i| inventory.get_target("t#{i}") }
      outputter.handle_event(type: :step_start, description: 'run task', targets: many)
      expect(output.string).to match(/Starting: run task on 6 targets/)
    end

    it 'prints step_finish with failure count and duration' do
      result_set = Bolt::ResultSet.new([Bolt::Result.new(target, message: 'ok', action: 'task')])
      outputter.handle_event(type: :step_finish, description: 'run task', result: result_set, duration: 1.5)
      expect(output.string).to match(/Finished: run task with 0 failures in 1.5 sec/)
    end
  end

  context 'plan lifecycle events' do
    it 'prints plan_start with the plan name' do
      outputter.handle_event(type: :plan_start, plan: 'myplan')
      expect(output.string).to match(/Starting: plan myplan/)
    end

    it 'does not print a message for plan_start when plan is nil' do
      outputter.handle_event(type: :plan_start, plan: nil)
      expect(output.string).to be_empty
    end

    it 'prints plan_finish with the plan name and duration' do
      outputter.handle_event(type: :plan_start, plan: 'myplan')
      output.truncate(0)
      output.rewind
      outputter.handle_event(type: :plan_finish, plan: 'myplan', duration: 2.5)
      expect(output.string).to match(/Finished: plan myplan in 2.5 sec/)
    end
  end

  context 'container events' do
    before(:each) { outputter.instance_variable_set(:@plan_depth, 1) }

    it 'prints container_start with the image name' do
      outputter.print_container_start(image: 'myimage:latest')
      expect(output.string).to match(/Starting: run container 'myimage:latest'/)
    end

    it 'prints container_finish for a successful ContainerResult' do
      result = Bolt::ContainerResult.new({ 'stdout' => '', 'stderr' => '' }, object: 'myimage')
      outputter.handle_event(type: :container_finish, result: result)
      expect(output.string).to match(/Finished: run container 'myimage' succeeded/)
    end

    it 'prints container_finish for a failed ContainerResult' do
      error = { '_error' => { 'msg' => 'boom', 'kind' => 'err', 'details' => {} } }
      result = Bolt::ContainerResult.new(error, object: 'myimage')
      outputter.handle_event(type: :container_finish, result: result)
      expect(output.string).to match(/Finished: run container 'myimage' failed/)
    end

    it 'unwraps ContainerFailure for container_finish' do
      inner = Bolt::ContainerResult.new({ 'stdout' => '', 'stderr' => '' }, object: 'img')
      failure = Bolt::ContainerFailure.new(inner)
      outputter.handle_event(type: :container_finish, result: failure)
      expect(output.string).to match(/Finished: run container 'img'/)
    end
  end

  describe '#print_container_result' do
    it 'prints a successful result with stdout and stderr' do
      result = Bolt::ContainerResult.new({ 'stdout' => "hello\n", 'stderr' => "warn\n" }, object: 'img')
      outputter.print_container_result(result)
      expect(output.string).to match(/STDOUT/)
      expect(output.string).to match(/hello/)
      expect(output.string).to match(/STDERR/)
    end

    it 'prints a completion message when stdout and stderr are empty' do
      result = Bolt::ContainerResult.new({ 'stdout' => '', 'stderr' => '' }, object: 'img')
      outputter.print_container_result(result)
      expect(output.string).to match(/completed successfully with no result/)
    end

    it 'prints a failed result with the error message' do
      error = { '_error' => { 'msg' => 'container crashed', 'kind' => 'err', 'details' => {} } }
      result = Bolt::ContainerResult.new(error, object: 'img')
      outputter.print_container_result(result)
      expect(output.string).to match(/Failed running container/)
      expect(output.string).to match(/container crashed/)
    end
  end

  describe '#print_plans' do
    it 'prints a list of plans and the modulepath' do
      outputter.print_plans(plans: [['mod::myplan', 'A plan']], modulepath: ['/path'])
      expect(output.string).to match(/Plans.*mod::myplan/m)
      expect(output.string).to match(/Modulepath.*\/path/m)
    end

    it 'prints a no-plans message when the list is empty' do
      outputter.print_plans(plans: [], modulepath: [])
      expect(output.string).to match(/No available plans/)
    end
  end

  describe '#print_new_plan' do
    it 'prints a creation message with show and run commands' do
      outputter.print_new_plan(name: 'mod::myplan', path: '/path/to/plan.yaml')
      expect(output.string).to match(/Created plan 'mod::myplan'/)
      expect(output.string).to match(/mod::myplan/)
    end
  end

  describe '#print_new_policy' do
    it 'prints a creation message with apply and show commands' do
      outputter.print_new_policy(name: 'mypolicy', path: '/path/to/policy.yaml')
      expect(output.string).to match(/Created policy 'mypolicy'/)
    end
  end

  describe '#print_policy_list' do
    it 'prints a sorted list of policies' do
      outputter.print_policy_list(policies: %w[zebra alpha], modulepath: ['/path'])
      expect(output.string).to match(/Policies.*alpha.*zebra/m)
    end

    it 'prints a no-policies message when the list is empty' do
      outputter.print_policy_list(policies: [], modulepath: ['/path'])
      expect(output.string).to match(/No available policies/)
    end
  end

  describe '#print_guide' do
    it 'prints documentation links when provided' do
      outputter.print_guide(topic: 'inventory', guide: "Guide text\n",
                            documentation: ['https://pup.pt/bolt-inventory'])
      expect(output.string).to match(/Documentation/)
      expect(output.string).to match(/https:\/\/pup\.pt\/bolt-inventory/)
    end
  end

  describe '#print_plan_result' do
    it 'prints a RunFailure by showing the result set' do
      err_result = Bolt::Result.new(target, error: { 'msg' => 'failed', 'kind' => 'err', 'details' => {} },
                                            action: 'task')
      result_set = Bolt::ResultSet.new([err_result])
      failure = Bolt::RunFailure.new(result_set, 'task', 'mytask')
      outputter.print_plan_result(double('plan_result', value: failure))
      expect(output.string).to match(/Failed on target1/)
    end

    it 'prints a ContainerResult' do
      container = Bolt::ContainerResult.new({ 'stdout' => 'hi', 'stderr' => '' }, object: 'img')
      outputter.print_plan_result(double('plan_result', value: container))
      expect(output.string).to match(/Finished running container/)
    end

    it 'prints a ContainerFailure' do
      inner = Bolt::ContainerResult.new(
        { '_error' => { 'msg' => 'oops', 'kind' => 'err', 'details' => {} } }, object: 'img'
      )
      failure = Bolt::ContainerFailure.new(inner)
      outputter.print_plan_result(double('plan_result', value: failure))
      expect(output.string).to match(/Failed running container/)
    end

    it 'prints a Bolt::ResultSet' do
      result_set = Bolt::ResultSet.new([Bolt::Result.new(target, message: 'ok', action: 'task')])
      outputter.print_plan_result(double('plan_result', value: result_set))
      expect(output.string).to match(/Finished on target1/)
    end

    it 'prints a Bolt::Result' do
      result = Bolt::Result.new(target, message: 'ok', action: 'task')
      outputter.print_plan_result(double('plan_result', value: result))
      expect(output.string).to match(/Finished on target1/)
    end

    it 'prints a Bolt::ApplyResult (matched as Bolt::Result)' do
      apply = Bolt::ApplyResult.new(target)
      outputter.print_plan_result(double('plan_result', value: apply))
      expect(output.string).to match(/Finished on target1/)
    end

    it 'prints a Bolt::Error via print_bolt_error' do
      error = Bolt::Error.new('something went wrong', 'bolt/error')
      outputter.print_plan_result(double('plan_result', value: error))
      expect(output.string).to match(/something went wrong/)
    end
  end

  describe '#fatal_error' do
    it 'prints the result set for a RunFailure' do
      err_result = Bolt::Result.new(target, error: { 'msg' => 'failed', 'kind' => 'err', 'details' => {} },
                                            action: 'task')
      result_set = Bolt::ResultSet.new([err_result])
      failure = Bolt::RunFailure.new(result_set, 'task', 'mytask')
      outputter.fatal_error(failure)
      expect(output.string).to match(/target1/)
    end

    it 'prints a backtrace when trace is enabled' do
      trace_outputter = Bolt::Outputter::Human.new(false, false, true, false, output)
      err = RuntimeError.new('oops')
      err.set_backtrace(%w[line1 line2])
      trace_outputter.fatal_error(err)
      expect(output.string).to match(/line1/)
      expect(output.string).to match(/line2/)
    end
  end

  describe '#print_error' do
    it 'prints the message to the stream' do
      outputter.print_error('something bad happened')
      expect(output.string).to match(/something bad happened/)
    end
  end

  describe '#print_bolt_error' do
    it 'prints the error message' do
      outputter.print_bolt_error(msg: 'parse error', details: {})
      expect(output.string).to match(/parse error/)
    end

    it 'includes file, line, and column when present' do
      outputter.print_bolt_error(msg: 'oops', details: { file: '/file.pp', line: 5, column: 3 })
      expect(output.string).to match(/file: \/file\.pp/)
      expect(output.string).to match(/line: 5/)
      expect(output.string).to match(/column: 3/)
    end

    it 'includes only file when line and column are absent' do
      outputter.print_bolt_error(msg: 'oops', details: { file: '/file.pp' })
      expect(output.string).to match(/file: \/file\.pp/)
      expect(output.string).not_to match(/line:/)
    end
  end

  describe '#print_prompt' do
    it 'prints the prompt to the stream' do
      outputter.print_prompt('Enter password: ')
      expect(output.string).to match(/Enter password/)
    end
  end

  describe '#print_prompt_error' do
    it 'prints the error message to the stream' do
      outputter.print_prompt_error('Invalid input')
      expect(output.string).to match(/Invalid input/)
    end
  end

  describe '#print_action_step' do
    it 'prints the step with an arrow prefix' do
      outputter.print_action_step('Running something')
      expect(output.string).to match(/→.*Running something/)
    end
  end

  describe '#print_action_error' do
    it 'prints the error with an arrow prefix' do
      outputter.print_action_error("Something failed\nWith details")
      expect(output.string).to match(/→.*Something failed/)
    end
  end

  context '#print_module_info' do
    let(:info) do
      {
        name: 'bolt/module',
        path: '/path/to/module',
        metadata: {
          'summary' => 'A test module',
          'version' => '1.0.0',
          'dependencies' => [
            {
              'name' => 'puppetlabs/stdlib',
              'version_requirement' => '>= 4.0.0 < 8.0.0'
            }
          ],
          'operatingsystem_support' => [
            {
              'operatingsystem' => 'RedHat',
              'operatingsystemrelease' => %w[
                5
                6
                7
              ]
            },
            {
              'operatingsystem' => 'CentOS'
            }
          ]
        },
        plans: [
          ['module::plan_one', 'a description'],
          ['module::plan_two', nil]
        ],
        tasks: [
          ['module::task_one', nil],
          ['module::task_two', 'a description']
        ]
      }
    end

    it 'prints module information' do
      outputter.print_module_info(**info)

      expect(output.string).to eq(<<~OUTPUT)
        bolt/module [1.0.0]
          A test module

        Tasks
          module::task_one
          module::task_two     a description
        
        Plans
          module::plan_one     a description
          module::plan_two

        Operating system support
          RedHat     5, 6, 7
          CentOS

        Dependencies
          puppetlabs/stdlib     >= 4.0.0 < 8.0.0

        Path
          /path/to/module
      OUTPUT
    end
  end
end
