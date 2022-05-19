# frozen_string_literal: true

require 'bolt_spec/bolt_context'
require 'bolt_spec/plans/mock_executor'
require 'bolt/pal'

# These helpers are intended to be used for plan unit testing without calling
# out to targets. It uses the BoltContext helper to set up a mock executor
# which allows calls to run_* functions to be stubbed for testing. The context
# helper also loads Bolt datatypes and plan functions to be used by the code
# being tested.
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
      Logging.init :trace, :debug, :info, :notice, :warn, :error, :fatal
    end

    # Provided as a class so expectations can be placed on it.
    class MockPuppetDBClient
      def initialize(config)
        @instance = MockPuppetDBInstance.new(config)
      end

      def instance(_instance)
        @instance
      end
    end

    class MockPuppetDBInstance
      attr_reader :config

      def initialize(config)
        @config = config
      end
    end

    def puppetdb_client
      @puppetdb_client ||= MockPuppetDBClient.new({})
    end

    def run_plan(name, params)
      pal = Bolt::PAL.new(
        Bolt::Config::Modulepath.new(config.modulepath),
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
