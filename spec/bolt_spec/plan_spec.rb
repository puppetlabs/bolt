# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/plans'

# Requires targets, plan_name, return_expects to be set.
# Requires expect_action to be defined.
shared_examples 'action tests' do
  it 'runs' do
    expect_action
    result = run_plan(plan_name, 'nodes' => targets)
    expect(result).to be_ok
    expect(result.value.class).to eq(Bolt::ResultSet)
  end

  it 'returns from a block' do
    expect_action.return do |targets:, **kwargs|
      Bolt::ResultSet.new(targets.map { |targ| Bolt::Result.new(targ, value: kwargs) })
    end
    result = run_plan(plan_name, 'nodes' => targets)
    expect(result).to be_ok
    expect(result.value.class).to eq(Bolt::ResultSet)
    results = result.value.result_hash
    targets.each do |target|
      expect(results[target].value).to eq(return_expects)
    end
  end

  it 'errors' do
    expect_action.error_with('msg' => 'failed', 'kind' => 'min')
    result = run_plan(plan_name, 'nodes' => targets)
    expect(result).not_to be_ok
  end

  it 'fails when not stubbed' do
    expect { run_plan(plan_name, 'nodes' => targets) }.to raise_error(RuntimeError, /Unexpected call to/)
  end

  it 'prints expected parameters when erroring' do
    params = Regexp.escape(expect_action.parameters.to_s)
    expect_action.not_be_called
    expect { run_plan(plan_name, 'nodes' => targets) }.to raise_error(RuntimeError, /#{params}/)
  end
end

describe "BoltSpec::Plans" do
  include BoltSpec::Files
  include BoltSpec::Plans

  def modulepath
    fixtures_path('bolt_spec')
  end

  let(:targets) { %w[foo bar] }

  it 'prints notice' do
    result = run_plan('plans', {})
    expect(result.value).to eq(nil)
  end

  it 'runs yaml plans' do
    expect_out_message.with_params("I'm a YAML plan")
    expect { run_plan('plans::yaml', {}) }.not_to raise_error
  end

  context 'with commands' do
    let(:plan_name) { 'plans::command' }
    let(:return_expects) { { command: 'echo hello', params: {} } }

    before(:each) do
      allow_command('hostname').with_targets(targets)
    end

    def expect_action
      expect_command('echo hello').with_params({})
    end

    include_examples 'action tests'

    it 'returns a default value' do
      expect_action.always_return(stdout: 'done')
      result = run_plan(plan_name, 'nodes' => targets)
      expect(result).to be_ok
      expect(result.value.class).to eq(Bolt::ResultSet)
      results = result.value.result_hash
      expected_result = { 'stdout' => 'done', 'stderr' => '', 'exit_code' => 0 }
      targets.each { |target| expect(results[target].value).to eq(expected_result) }
    end

    it 'returns different values' do
      expect_action.return_for_targets(
        targets[0] => { 'stdout' => 'done' },
        targets[1] => { 'stderr' => 'running' }
      )
      result = run_plan(plan_name, 'nodes' => targets)
      expect(result).to be_ok
      expect(result.value.class).to eq(Bolt::ResultSet)
      results = result.value.result_hash
      expect(results[targets[0]]['stdout']).to eq('done')
      expect(results[targets[1]]['stderr']).to eq('running')
    end
  end

  context 'with scripts' do
    let(:plan_name) { 'plans::script' }
    let(:return_expects) { { script: 'plans/script', params: { 'arguments' => ['arg'] } } }

    before(:each) do
      allow_script('plans/dir/prep').with_targets(targets)
    end

    def expect_action
      expect_script('plans/script').with_params('arguments' => ['arg'])
    end

    include_examples 'action tests'
  end

  context 'with tasks' do
    let(:plan_name) { 'plans::task' }
    let(:return_expects) { { task: 'plans::foo', params: { 'arg1' => true } } }

    before(:each) do
      allow_task('plans::prep').with_targets(targets)
    end

    def expect_action
      expect_task('plans::foo').with_params('arg1' => true)
    end

    include_examples 'action tests'

    it 'returns a default value' do
      expect_action.always_return('status' => 'done')
      result = run_plan(plan_name, 'nodes' => targets)
      expect(result).to be_ok
      expect(result.value.class).to eq(Bolt::ResultSet)
      results = result.value.result_hash
      targets.each { |target| expect(results[target].value).to eq('status' => 'done') }
    end

    it 'returns different values' do
      expect_action.return_for_targets(
        targets[0] => { 'status' => 'done' },
        targets[1] => { 'status' => 'running' }
      )
      result = run_plan(plan_name, 'nodes' => targets)
      expect(result).to be_ok
      expect(result.value.class).to eq(Bolt::ResultSet)
      results = result.value.result_hash
      expect(results[targets[0]]['status']).to eq('done')
      expect(results[targets[1]]['status']).to eq('running')
    end
  end

  context 'with downloads' do
    let(:project) { Bolt::Project.default_project }
    let(:plan_name) { 'plans::download' }
    let(:destination) { project.downloads + 'foo' }
    let(:return_expects) { { source: 'plans/script', destination: destination, params: {} } }

    before(:each) do
      allow_download('plans/dir/prep').with_targets(targets)
    end

    def expect_action
      expect_download('plans/script').with_destination(destination).with_params({})
    end

    include_examples 'action tests'

    # always_return and return_for_Targets are not supported with download
    it 'rejects always_return' do
      expect {
        expect_action.always_return('status' => 'done')
      }.to raise_error('Download result cannot be changed')
    end

    it 'rejects return_for_targets' do
      expect {
        expect_action.return_for_targets(
          targets[0] => { 'status' => 'done' },
          targets[1] => { 'status' => 'running' }
        )
      }.to raise_error('Download result cannot be changed')
    end
  end

  context 'with uploads' do
    let(:plan_name) { 'plans::upload' }
    let(:return_expects) { { source: 'plans/script', destination: '/d', params: {} } }

    before(:each) do
      allow_upload('plans/dir/prep').with_targets(targets)
    end

    def expect_action
      expect_upload('plans/script').with_destination('/d').with_params({})
    end

    include_examples 'action tests'

    # always_return and return_for_targets are not supported with upload
    it 'rejects always_return' do
      expect {
        expect_action.always_return('status' => 'done')
      }.to raise_error('Upload result cannot be changed')
    end

    it 'rejects return_for_targets' do
      expect {
        expect_action.return_for_targets(
          targets[0] => { 'status' => 'done' },
          targets[1] => { 'status' => 'running' }
        )
      }.to raise_error('Upload result cannot be changed')
    end
  end

  context 'with apply_preps' do
    let(:plan_name) { 'plans::apply_prep' }

    it 'runs' do
      allow_apply_prep
      result = run_plan(plan_name, 'nodes' => targets)
      expect(result).to be_ok
    end

    it 'fails' do
      expect { run_plan(plan_name, 'nodes' => targets) }.to raise_error(RuntimeError, /Unexpected call to/)
    end
  end

  context 'with applies' do
    let(:plan_name) { 'plans::apply' }

    it 'runs' do
      allow_apply
      result = run_plan(plan_name, 'nodes' => targets)
      expect(result).to be_ok
      expect(result.value.class).to eq(Bolt::ResultSet)
    end

    it 'fails' do
      result = run_plan(plan_name, 'nodes' => targets)
      expect(result).not_to be_ok
    end
  end

  context 'with get_resources' do
    let(:plan_name) { 'plans::get_resources' }

    it 'runs' do
      allow_get_resources
      result = run_plan(plan_name, 'nodes' => targets)
      expect(result).to be_ok
    end

    it 'fails' do
      expect { run_plan(plan_name, 'nodes' => targets) }.to raise_error(RuntimeError, /Unexpected call to/)
    end
  end

  context 'with out::message' do
    let(:plan_name) { 'plans::out_message' }
    let(:message) { 'foo' }
    let(:other_message) { 'bar' }

    it 'allows with params' do
      allow_out_message.with_params(message)
      result = run_plan(plan_name, 'messages' => [message])
      expect(result).to be_ok
    end

    it 'allows any out message' do
      allow_any_out_message
      result = run_plan(plan_name, 'messages' => [message])
      expect(result).to be_ok
    end

    it 'errors when not allowed' do
      expect { run_plan(plan_name, 'messages' => [message]) }.to raise_error(RuntimeError, /Unexpected call to/)
    end

    it 'expects with params' do
      expect_out_message.with_params(message)
      result = run_plan(plan_name, 'messages' => [message])
      expect(result).to be_ok
    end

    it 'expects multiple times with params' do
      expect_out_message.be_called_times(2).with_params(message)
      result = run_plan(plan_name, 'messages' => [message, message])
      expect(result).to be_ok
    end

    it 'expects with different params' do
      expect_out_message.with_params(message)
      expect_out_message.with_params(other_message)
      result = run_plan(plan_name, 'messages' => [message, other_message])
      expect(result).to be_ok
    end

    it 'errors when not expected' do
      expect_out_message.not_be_called
      expect { run_plan(plan_name, 'messages' => [message]) }
        .to raise_error(RuntimeError, /Expected out::message to be called 0 times/)
    end

    it 'errors with wrong params' do
      expect_out_message.with_params(other_message)
      expect { run_plan(plan_name, 'messages' => [message]) }
        .to raise_error(RuntimeError, /Expected out::message to be called 1 times with parameters #{other_message}/)
    end
  end

  context 'with plan calling sub-plan' do
    let(:plan_name) { 'plans::plan_calling_plan' }
    let(:sub_plan_name) { 'plans::command' }

    it 'sets execute_any_plan to true, by default' do
      expect(executor.execute_any_plan).to eq(true)
    end

    it 'execute_no_plan changes flag' do
      execute_no_plan
      expect(executor.execute_any_plan).to eq(false)
    end

    it 'execute_any_plan changes flag' do
      execute_no_plan
      expect(executor.execute_any_plan).to eq(false)
      execute_any_plan
      expect(executor.execute_any_plan).to eq(true)
    end

    it 'allows any sub-plan, by default, without mocking' do
      expect_command('hostname').with_targets(targets)
      expect_command('echo hello').with_targets(targets)
      result = run_plan(plan_name, 'targets' => targets)
      expect(result).to be_ok
    end

    it 'allows with params' do
      allow_plan(sub_plan_name).with_params('targets' => targets)
      result = run_plan(plan_name, 'targets' => targets)
      expect(result).to be_ok
    end

    it 'allows any plan' do
      allow_any_plan
      result = run_plan(plan_name, 'targets' => targets)
      expect(result).to be_ok
    end

    it 'expects with params' do
      expect_plan(sub_plan_name).with_params('nodes' => targets)
      result = run_plan(plan_name, 'targets' => targets)
      expect(result).to be_ok
    end

    it 'expects with_targets for plan with TargetSpec targets' do
      expect_plan('plans::plan_with_targets').with_targets(targets)
      result = run_plan('plans::plan_calling_targets', 'targets' => targets)
      expect(result).to be_ok
    end

    it 'expects with_targets for plan with TargetSpec nodes' do
      expect_plan(sub_plan_name).with_targets(targets)
      result = run_plan(plan_name, 'targets' => targets)
      expect(result).to be_ok
    end

    it 'always returns data' do
      expect_plan(sub_plan_name)
        .with_params('nodes' => targets)
        .always_return('status' => 'done')
      result = run_plan(plan_name, 'targets' => targets)
      expect(result).to be_ok
      expect(result.value).to eq('status' => 'done')
    end

    it 'returns data from a block' do
      expect_plan(sub_plan_name).return do |_plan, _params|
        Bolt::PlanResult.new({ 'returnfrom' => 'block' }, 'success')
      end
      result = run_plan(plan_name, 'targets' => targets)
      expect(result).to be_ok
      expect(result.value).to eq('returnfrom' => 'block')
    end

    it 'errors when using return_for_targets' do
      err = /return_for_targets is not implemented for plan spec tests \(allow_plan, expect_plan, allow_any_plan, etc\)/
      expect {
        expect_plan(sub_plan_name).return_for_targets(
          'foo' => { 'status' => 'done' },
          'bar' => { 'value' => 'hooray' }
        )
      }.to raise_error(RuntimeError, err)
    end

    it 'correctly calculates be_called_times when called' do
      expect_plan(sub_plan_name).be_called_times(1)
      result = run_plan(plan_name, 'targets' => targets)
      expect(result).to be_ok
    end

    it 'correctly calculates be_called_times when not' do
      expect_plan('uncalled::plan_name').be_called_times(0)
      expect_command('hostname').with_targets(targets)
      expect_command('echo hello').with_targets(targets)
      result = run_plan(plan_name, 'targets' => targets)
      expect(result).to be_ok
    end

    it 'correctly evaluates not_be_called when the plan is not called' do
      expect_plan('uncalled::plan_name').not_be_called
      expect_command('hostname').with_targets(targets)
      expect_command('echo hello').with_targets(targets)
      result = run_plan(plan_name, 'targets' => targets)
      expect(result).to be_ok
    end

    it 'errors when plan is called, but not_be_called is expected' do
      expect_plan(sub_plan_name).not_be_called
      expect { run_plan(plan_name, 'targets' => targets) }
        .to raise_error(RuntimeError, /Expected plans::command to be called 0 times/)
    end

    it 'errors with wrong params' do
      params = { 'bad_expected' => 'params' }
      expect_plan(sub_plan_name).with_params(params)
      expect { run_plan(plan_name, 'targets' => targets) }
        .to raise_error(RuntimeError, /Expected plans::command to be called 1 times with parameters #{params}/)
    end

    it 'captures fail_plan()' do
      result = run_plan('plans::plan_fails', {})
      expect(result).not_to be_ok
      expect(result.class).to eq(Bolt::PlanResult)
      expect(result.status).to eq('failure')
      expect(result.value.class).to eq(Bolt::PlanFailure)
      expect(result.value.msg).to eq('expected failure')
      expect(result.value.kind).to eq('bolt/plan-failure')
    end

    it 'errors when error_with' do
      expect_plan(sub_plan_name).error_with('msg' => 'failed', 'kind' => 'bolt/plan-failure')
      result = run_plan(plan_name, 'targets' => targets)
      expect(result.class).to eq(Bolt::PlanResult)
      expect(result.status).to eq('failure')
      expect(result.value.class).to eq(Bolt::PlanFailure)
      expect(result.value.msg).to eq('failed')
      expect(result.value.kind).to eq('bolt/plan-failure')
      expect(result).not_to be_ok
    end

    context 'with execute_no_plan' do
      before(:each) do
        execute_no_plan
      end

      it 'errors if unexpected plan is called' do
        err = "Unexpected call to 'run_plan(plans::command, {\"nodes\"=>[\"foo\", \"bar\"]})'"
        expect { run_plan(plan_name, 'targets' => targets) }
          .to raise_error(RuntimeError, err)
      end

      it 'allows with params still mocks' do
        allow_plan(sub_plan_name).with_params('targets' => targets)
        result = run_plan(plan_name, 'targets' => targets)
        expect(result).to be_ok
      end

      it 'expects with params still mocks' do
        expect_plan(sub_plan_name).with_params('nodes' => targets)
        result = run_plan(plan_name, 'targets' => targets)
        expect(result).to be_ok
      end

      it 'allows any plan' do
        allow_any_plan
        result = run_plan(plan_name, 'targets' => targets)
        expect(result).to be_ok
      end
    end
  end
end
