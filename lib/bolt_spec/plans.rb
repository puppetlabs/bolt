# frozen_string_literal: true

require 'bolt_spec/bolt_context'
require 'bolt_spec/plans/mock_executor'
require 'bolt/pal'

# These helpers are intended to be used for plan unit testing without calling
# out to target nodes. It uses the BoltContext helper to set up a mock executor
# which allows calls to run_* functions to be stubbed for testing. The context
# helper also loads Bolt datatypes and plan functions to be used by the code
# being tested.
#
# Stub matching
#
# Stubs match invocations of run_* functions by default matching any call but
# with_targets and with_params helpers can further restrict the stub to match
# more exact invocations. It's possible a call to run_* could match multiple
# stubs. In this case the mock executor will first check for stubs specifically
# matching the task being run after which it will use the last stub that
# matched
#
#
# allow vs expect
#
# Stubs have two general modes bases on whether the test is making assertions
# on whether function was called. Allow stubs allow the run_* invocation  to
# be called any number of times while expect stubs will fail if no run_*
# invocation matches them. The be_called_times(n) stub method can be used to
# ensure an allow stub is not called more than n times or that an expect stub
# is called exactly n times.
#
# Configuration
#
#  To configure Puppet and Bolt at the beginning of tests, add the following
#  line to your spec_helper.rb:
#
#  BoltSpec::Plans.init
#
#  By default the plan helpers use the modulepath set up for rspec-puppet and
#  an otherwise empty bolt config and inventory. To create your own values for
#  these override the modulepath, config, or inventory methods.
#
# Sub-plan Execution
#
#  When testing a plan, often times those plans call other plans in order to
#  build complex workflows. To support this we offer running in two different
#  modes:
#    execute_any_plan (default) - This mode will execute any plan that is encountered
#      without having to be stubbed/mocked. This default mode allows for plan control
#      flow to behave as normal. If you choose to stub/mock out a sub-plan in this mode
#      that will be honored and the sub-plan will not be executed. We will use the modifiers
#      on the stub to check for the conditions specified (example: be_called_times(3))
#
#    execute_no_plan - This mode will not execute a plans that it encounters. Instead, when
#      a plan is encountered it will throw an error unless the plan is mocked out. This
#      mode is useful for ensuring that there are no plans called that you do not expect.
#      This plan requires authors to mock out all sub-plans that may be invoked when running
#      tests.
#
#  TODO:
#  - Allow description based stub matching
#  - Better testing of plan errors
#  - Better error collection around call counts. Show what stubs exists and more than a single failure
#  - Allow stubbing with a block(at the double level? As a matched stub?)
#  - package code so that it can be used for testing modules outside of this repo
#  - set subject from describe and provide matchers similar to rspec puppets function tests
#  - Allow specific plans to be executed when running in execute_no_plan mode.
#
#  MAYBE TODO?:
#  - validate call expectations at the end of the example instead of in run_plan
#  - resultset matchers to help testing canary like plans?
#  - inventory matchers to help testing plans that change inventory
#
# Flags:
# - execute_any_plan: execute any plan that is encountered unless it is mocked (default)
# - execute_no_plan: throw an error if a plan is encountered that is not stubbed
#
# Stubs:
# - allow_command(cmd), expect_command(cmd): expect the exact command
# - allow_plan(plan), expect_plan(plan): expect the named plan
# - allow_script(script), expect_script(script): expect the script as <module>/path/to/file
# - allow_task(task), expect_task(task): expect the named task
# - allow_download(file), expect_download(file): expect the identified source file
# - allow_upload(file), expect_upload(file): expect the identified source file
# - allow_apply_prep: allows `apply_prep` to be invoked in the plan but does not allow modifiers
# - allow_apply: allows `apply` to be invoked in the plan but does not allow modifiers
# - allow_out_message, expect_out_message: expect a message to be passed to out::message (only modifiers are
#   be_called_times(n), with_params(params), and not_be_called)
#
# Stub modifiers:
# - be_called_times(n): if allowed, fail if the action is called more than 'n' times
#                       if expected, fail unless the action is called 'n' times
# - not_be_called: fail if the action is called
# - with_targets(targets): target or list of targets that you expect to be passed to the action
#                          plan: does not support this modifier
# - with_params(params): list of params and metaparams (or options) that you expect to be passed to the action.
#                        Corresponds to the action's last argument.
# - with_destination(dest): for upload_file and download_file, the expected destination path
# - always_return(value): return a Bolt::ResultSet of Bolt::Result objects with the specified value Hash
#                         plan: returns a Bolt::PlanResult with the specified value with a status of 'success'
#                         command and script: only accept 'stdout' and 'stderr' keys
#                         upload: does not support this modifier
#                         download: does not support this modifier
# - return_for_targets(targets_to_values): return a Bolt::ResultSet of Bolt::Result objects from the Hash mapping
#                                          targets to their value Hashes
#                                          command and script: only accept 'stdout' and 'stderr' keys
#                                          upload: does not support this modifier
#                                          download: does not support this modifier
#                                          plan: does not support this modifier
# - return(&block): invoke the block to construct a Bolt::ResultSet. The blocks parameters differ based on action
#                   command: `{ |targets:, command:, params:| ... }`
#                   plan: `{ |plan:, params:| ... }`
#                   script: `{ |targets:, script:, params:| ... }`
#                   task: `{ |targets:, task:, params:| ... }`
#                   upload: `{ |targets:, source:, destination:, params:| ... }`
#                   download: `{ |targets:, source:, destination:, params:| ... }`
# - error_with(err): return a failing Bolt::ResultSet, with Bolt::Result objects with the identified err hash
#                    plans will throw a Bolt::PlanFailure that will be returned as the value of
#                    the Bolt::PlanResult object with a status of 'failure'.
#
# Example:
#   describe "my_plan" do
#     it 'should return' do
#       allow_task('my_task').always_return({'result_key' => 10})
#       expect(run_plan('my_plan', { 'param1' => 10 })).to be
#     end
#
#     it 'should call task with param1' do
#       expect_task('my_task').with_params('param1' => 10).always_return({'result_key' => 10})
#       expect(run_plan('my_plan', { 'param1' => 10 })).to eq(10)
#     end
#
#     it 'should call task with param1 once' do
#       expect_task('my_task').with_params('param1' => 10).always_return({'result_key' => 10}).be_called_times(1)
#       expect(run_plan('my_plan', { 'param1' => 10 })).to eq(10)
#     end
#
#     it 'should not_call task with 100' do
#       allow_task('my_task').always_return({'result_key' => 10})
#       # Any call with param1 => 100 will match this since it's added second
#       expect_task('my_task').with_params('param1' => 100).not_be_called
#       expect(run_plan('my_plan', { 'param1' => 10 })).to eq(10)
#     end
#
#     it 'should be called on both node1 and node2' do
#       expect_task('my_task').with_targets(['node1', 'node2']).always_return({'result_key' => 10})
#       expect(run_plan('my_plan', { 'param1' => 10 })).to eq(10)
#     end
#
#     it 'should average results from targets' do
#       expect_task('my_task').return_for_targets({
#         'node1' => {'result_key' => 20},
#         'node2' => {'result_key' => 6} })
#       expect(run_plan('my_plan', { 'param1' => 10 })).to eq(13)
#     end
#
#     it 'should construct a custom return value' do
#       expect_task('my_task').return do |targets:, task:, params:|
#         Bolt::ResultSet.new(targets.map { |targ| Bolt::Result.new(targ, {'result_key' => 10'})})
#       end
#       expect(run_plan('my_plan', { 'param1' => 10 })).to eq(10)
#     end
#
#     it 'expects multiple messages to out::message' do
#       expect_out_message.be_called_times(2).with_params(message)
#       result = run_plan(plan_name, 'messages' => [message, message])
#       expect(result).to be_ok
#     end
#
#     it 'expects a sub-plan to be called' do
#       expect_plan('module::sub_plan').with_params('targets' => ['foo']).be_called_times(1)
#       result = run_plan('module::main_plan', 'targets' => ['foo'])
#       expect(result).to be_ok
#       expect(result.class).to eq(Bolt::PlanResult)
#       expect(result.value).to eq('foo' => 'is_good')
#       expect(result.status).to eq('success')
#     end
#
#     it 'error when sub-plan is called' do
#       execute_no_plan
#       err = 'Unexpected call to 'run_plan(module::sub_plan, {\"targets\"=>[\"foo\"]})'
#       expect { run_plan('module::main_plan', 'targets' => ['foo']) }
#         .to raise_error(RuntimeError, err)
#     end
#
#     it 'errors when plan calls fail_plan()' do
#       result = run_plan('module::calls_fail_plan', {})
#       expect(result).not_to be_ok
#       expect(result.class).to eq(Bolt::PlanResult)
#       expect(result.status).to eq('failure')
#       expect(result.value.class).to eq(Bolt::PlanFailure)
#       expect(result.value.msg).to eq('failure message passed to fail_plan()')
#       expect(result.value.kind).to eq('bolt/plan-failure')
#     end
#   end
#
# See spec/bolt_spec/plan_spec.rb for more examples.
module BoltSpec
  module Plans
    include BoltSpec::BoltContext

    def self.init
      # Ensure tasks are enabled when rspec-puppet sets up an environment so we get task loaders.
      # Note that this is probably not safe to do in modules that also test Puppet manifest code.
      Bolt::PAL.load_puppet
      Puppet[:tasks] = true

      # Ensure logger is initialized with Puppet levels so 'notice' works when running plan specs.
      Logging.init :debug, :info, :notice, :warn, :error, :fatal, :any
    end

    # Provided as a class so expectations can be placed on it.
    class MockPuppetDBClient
      attr_reader :config

      def initialize(config)
        @config = config
      end
    end

    def puppetdb_client
      @puppetdb_client ||= MockPuppetDBClient.new(Bolt::PuppetDB::Config.new({}))
    end

    def run_plan(name, params)
      pal = Bolt::PAL.new(
        config.modulepath,
        config.hiera_config,
        config.project.resource_types,
        config.compile_concurrency,
        config.trusted_external,
        config.apply_settings,
        config.project
      )

      result = executor.with_plan_allowed_exec(name, params) do
        pal.run_plan(name, params, executor, inventory, puppetdb_client)
      end

      if executor.error_message
        raise executor.error_message
      end

      begin
        executor.assert_call_expectations
      rescue StandardError => e
        raise "#{e.message}\nPlan result: #{result}\n#{e.backtrace.join("\n")}"
      end

      result
    end

    def allow_apply_prep
      allow_task('apply_helpers::custom_facts')
      nil
    end

    def allow_apply
      executor.stub_apply
      nil
    end

    def allow_get_resources
      allow_task('apply_helpers::query_resources')
      nil
    end

    # Flag for the default behavior of executing sub-plans during testing
    # By *default* we allow any sub-plan to be executed, no mocking required.
    # Users can still mock out plans in this mode and the mocks will check for
    # parameters and return values like normal. However, if a plan isn't explicitly
    # mocked out, it will be executed.
    def execute_any_plan
      executor.execute_any_plan = true
    end

    # If you want to explicitly mock out all of the sub-plan calls, then
    # call this prior to calling `run_plan()` along with setting up any
    # mocks that you require.
    # In this mode, any plan that is not explicitly mocked out will not be executed
    # and an error will be thrown.
    def execute_no_plan
      executor.execute_any_plan = false
    end

    # intended to be private below here
  end
end
