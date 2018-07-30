# frozen_string_literal: true

require 'bolt_spec/plans/mock_executor'
require 'bolt/config'

# These helpers are intended to be used for plan unit testing without calling
# out to target nodes. It accomplishes this by replacing bolt's executor with a
# mock executor. The mock executor allows calls to run_* functions to be
# stubbed out for testing. By default this executor will fail on any run_*
# call but stubs can be set up with allow_* and expect_* functions.
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
#  By default the plan helpers use the modulepath set up for rspec-puppet and
#  an otherwise empty bolt config and inventory. To create your own values for
#  these override the modulepath, config, or inventory methods.
#
#
#  TODO:
#  - allow stubbing for commands, scripts and file uploads
#  - Allow description based stub matching
#  - Better testing of plan errors
#  - Better error collection around call counts. Show what stubs exists and more than a single failure
#  - Allow stubbing with a block(at the double level? As a matched stub?)
#  - package code so that it can be used for testing modules outside of this repo
#  - set subject from describe and provide matchers similar to rspec puppets function tests
#
#  MAYBE TODO?:
#  - allow stubbing for subplans
#  - validate call expectations at the end of the example instead of in run_plan
#  - resultset matchers to help testing canary like plans?
#  - inventory matchers to help testing plans that change inventory
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
#   end
#
module BoltSpec
  module Plans
    # Override in your tests if needed
    def modulepath
      [RSpec.configuration.module_path]
    rescue NoMethodError
      raise "RSpec.configuration.module_path not defined set up rspec puppet or define modulepath for this test"
    end

    # Override in your tests
    def config
      config = Bolt::Config.new(Bolt::Boltdir.new('.'), {})
      config.modulepath = modulepath
      config
    end

    # Override in your tests
    def inventory
      @inventory ||= Bolt::Inventory.new({})
    end

    def puppetdb_client
      @puppetdb_client ||= mock('puppetdb_client')
    end

    def run_plan(name, params)
      pal = Bolt::PAL.new(config.modulepath, config.hiera_config)
      result = pal.run_plan(name, params, executor, inventory, puppetdb_client)

      if executor.error_message
        raise executor.error_message
      end

      executor.assert_call_expectations

      result
    end

    # Allowed task stubs can be called up to be_called_times number
    # of times
    def allow_task(task_name)
      executor.stub_task(task_name).add_stub
    end

    # Expected task stubs must be called exactly the expected number of times
    # or at least once without be_called_times
    def expect_task(task_name)
      allow_task(task_name).expect_call
    end

    # This stub will catch any task call if there are no stubs specifically for that task
    def allow_any_task
      executor.stub_task(:default).add_stub
    end

    # Example helpers to mock other run functions
    # The with_targets method  makes sense for all stubs
    # with_params could be reused for options
    # They probably need special stub methods for other arguments through

    # Scripts can be mocked like tasks by their name
    # arguments is an array instead of a hash though
    # so it probably should be set separately
    # def allow_script(script_name)
    #
    # file uploads have a single destination and no arguments
    # def allow_file_upload(source_name)
    #
    # Most of the information in commands is in the command string itself
    # we may need more flexible allows than just the name/command string
    # Only option params exist on a command.
    # def allow_command(command)
    # def allow_command_matching(command_regex)
    # def allow_command(&block)
    #
    # Plan execution does not flow through the executor mocking may make sense but
    # will be a separate effort.
    # def allow_plan(plan_name)

    # intended to be private below here
    def executor
      @executor ||= BoltSpec::Plans::MockExecutor.new
    end
  end
end
