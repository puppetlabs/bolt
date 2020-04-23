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
# - allow_out_message, expect_out_message: expect a message to be passed to out::message (only modifiers are
#   be_called_times(n), with_params(params), and not_be_called)
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

#     it 'expects multiple messages to out::message' do
#       expect_out_message.be_called_times(2).with_params(message)
#       result = run_plan(plan_name, 'messages' => [message, message])
#       expect(result).to be_ok
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

    # Plan execution does not flow through the executor mocking may make sense but
    # will be a separate effort.
    # def allow_plan(plan_name)

    # intended to be private below here
  end
end
