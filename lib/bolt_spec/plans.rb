# frozen_string_literal: true

require 'bolt_spec/plans/mock_executor'
require 'bolt/config'
require 'bolt/inventory'
require 'bolt/pal'

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
#  To configure Puppet and Bolt at the beginning of tests, add the following
#  line to your spec_helper.rb:
#
#  BoltSpec::Plans.init
#
#  By default the plan helpers use the modulepath set up for rspec-puppet and
#  an otherwise empty bolt config and inventory. To create your own values for
#  these override the modulepath, config, or inventory methods.
#
#
#  TODO:
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
# Stubs:
# - allow_command(cmd), expect_command(cmd): expect the exact command
# - allow_script(script), expect_script(script): expect the script as <module>/path/to/file
# - allow_task(task), expect_task(task): expect the named task
# - allow_upload(file), expect_upload(file): expect the identified source file
# - allow_apply_prep: allows `apply_prep` to be invoked in the plan but does not allow modifiers
# - allow_apply: allows `apply` to be invoked in the plan but does not allow modifiers
#
# Stub modifiers:
# - be_called_times(n): if allowed, fail if the action is called more than 'n' times
#                       if expected, fail unless the action is called 'n' times
# - not_be_called: fail if the action is called
# - with_targets(targets): target or list of targets that you expect to be passed to the action
# - with_params(params): list of params and metaparams (or options) that you expect to be passed to the action.
#                        Corresponds to the action's last argument.
# - with_destination(dest): for upload_file, the expected destination path
# - always_return(value): return a Bolt::ResultSet of Bolt::Result objects with the specified value Hash
#                         command and script: only accept 'stdout' and 'stderr' keys
#                         upload: does not support this modifier
# - return_for_targets(targets_to_values): return a Bolt::ResultSet of Bolt::Result objects from the Hash mapping
#                                          targets to their value Hashes
#                                          command and script: only accept 'stdout' and 'stderr' keys
#                                          upload: does not support this modifier
# - return(&block): invoke the block to construct a Bolt::ResultSet. The blocks parameters differ based on action
#                   command: `{ |targets:, command:, params:| ... }`
#                   script: `{ |targets:, script:, params:| ... }`
#                   task: `{ |targets:, task:, params:| ... }`
#                   upload: `{ |targets:, source:, destination:, params:| ... }`
# - error_with(err): return a failing Bolt::ResultSet, with Bolt::Result objects with the identified err hash
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
#   end
#
# See spec/bolt_spec/plan_spec.rb for more examples.
module BoltSpec
  module Plans
    def self.init
      # Ensure tasks are enabled when rspec-puppet sets up an environment so we get task loaders.
      # Note that this is probably not safe to do in modules that also test Puppet manifest code.
      Bolt::PAL.load_puppet
      Puppet[:tasks] = true

      # Ensure logger is initialized with Puppet levels so 'notice' works when running plan specs.
      Logging.init :debug, :info, :notice, :warn, :error, :fatal, :any
    end

    # Override in your tests if needed
    def modulepath
      [RSpec.configuration.module_path]
    rescue NoMethodError
      raise "RSpec.configuration.module_path not defined set up rspec puppet or define modulepath for this test"
    end

    # Override in your tests
    def config
      @config ||= begin
        conf = Bolt::Config.new(Bolt::Boltdir.new('.'), {})
        conf.modulepath = [modulepath].flatten
        conf
      end
    end

    # Override in your tests
    def inventory
      @inventory ||= Bolt::Inventory.new({})
    end

    # Provided as a class so expectations can be placed on it.
    class MockPuppetDBClient; end

    def puppetdb_client
      @puppetdb_client ||= MockPuppetDBClient.new
    end

    def run_plan(name, params)
      pal = Bolt::PAL.new(config.modulepath, config.hiera_config, config.boltdir.resource_types)
      result = pal.run_plan(name, params, executor, inventory, puppetdb_client)

      if executor.error_message
        raise executor.error_message
      end

      begin
        executor.assert_call_expectations
      rescue StandardError => e
        raise "#{e.message}\nPlan result: #{result}"
      end

      result
    end

    MOCKED_ACTIONS.each do |action|
      # Allowed action stubs can be called up to be_called_times number of times
      define_method :"allow_#{action}" do |object|
        executor.send(:"stub_#{action}", object).add_stub
      end

      # Expected action stubs must be called exactly the expected number of times
      # or at least once without be_called_times
      define_method :"expect_#{action}" do |object|
        send(:"allow_#{action}", object).expect_call
      end

      # This stub will catch any action call if there are no stubs specifically for that task
      define_method :"allow_any_#{action}" do
        executor.send(:"stub_#{action}", :default).add_stub
      end
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

    # Example helpers to mock other run functions
    # The with_targets method makes sense for all stubs
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
      @executor ||= BoltSpec::Plans::MockExecutor.new(modulepath)
    end
  end
end
