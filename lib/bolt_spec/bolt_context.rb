# frozen_string_literal: true

require 'bolt_spec/plans/mock_executor'
require 'bolt/config'
require 'bolt/inventory'
require 'bolt/pal'
require 'bolt/plugin'

# This helper is used to create the Bolt context necessary to load Bolt plan
# datatypes and functions. It accomplishes this by replacing bolt's executor
# with a mock executor. The mock executor allows calls to run_* functions to be
# stubbed out for testing. By default this executor will fail on any run_* call
# but stubs can be set up with allow_* and expect_* functions.
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
# Stubs:
# - allow_command(cmd), expect_command(cmd): expect the exact command
# - allow_script(script), expect_script(script): expect the script as <module>/path/to/file
# - allow_task(task), expect_task(task): expect the named task
# - allow_download(file), expect_download(file): expect the identified source file
# - allow_upload(file), expect_upload(file): expect the identified source file
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
# - with_destination(dest): for upload_file and download_file, the expected destination path
# - always_return(value): return a Bolt::ResultSet of Bolt::Result objects with the specified value Hash
#                         command and script: only accept 'stdout' and 'stderr' keys
#                         upload: does not support this modifier
#                         download: does not support this modifier
# - return_for_targets(targets_to_values): return a Bolt::ResultSet of Bolt::Result objects from the Hash mapping
#                                          targets to their value Hashes
#                                          command and script: only accept 'stdout' and 'stderr' keys
#                                          upload: does not support this modifier
#                                          download: does not support this modifier
# - return(&block): invoke the block to construct a Bolt::ResultSet. The blocks parameters differ based on action
#                   command: `{ |targets:, command:, params:| ... }`
#                   script: `{ |targets:, script:, params:| ... }`
#                   task: `{ |targets:, task:, params:| ... }`
#                   upload: `{ |targets:, source:, destination:, params:| ... }`
#                   download: `{ |targets:, source:, destination:, params:| ... }`
# - error_with(err): return a failing Bolt::ResultSet, with Bolt::Result objects with the identified err hash
#
# Example:
#
#  describe "mymod::myfunction" do
#   include BoltSpec::BoltContext
#
#    around :each do |example|
#      in_bolt_context do
#        example.run
#      end
#    end
#
#    it "bolt_context runs a Puppet function with Bolt datatypes" do
#      expect_out_message.with_params("Loaded TargetSpec localhost")
#      is_expected.to run.with_params('localhost').and_return('localhost')
#    end
#  end

module BoltSpec
  module BoltContext
    def setup
      unless @loaded
        # This is slow so don't do it until we have to
        Bolt::PAL.load_puppet
        @loaded = true
      end
    end

    def in_bolt_context(&block)
      setup
      old_modpath = RSpec.configuration.module_path
      old_tasks = Puppet[:tasks]

      # Set the things
      Puppet[:tasks] = true
      RSpec.configuration.module_path = [modulepath, Bolt::Config::BOLTLIB_PATH].join(File::PATH_SEPARATOR)
      opts = {
        bolt_executor: executor,
        bolt_inventory: inventory,
        bolt_pdb_client: nil,
        apply_executor: nil
      }
      Puppet.override(opts, &block)

      # Unset the things
      RSpec.configuration.module_path = old_modpath
      Puppet[:tasks] = old_tasks
    end

    # Override in your tests if needed
    def modulepath
      [RSpec.configuration.module_path]
    rescue NoMethodError
      raise "RSpec.configuration.module_path not defined set up rspec puppet or define modulepath for this test"
    end

    def executor
      @executor ||= BoltSpec::Plans::MockExecutor.new(modulepath)
    end

    # Override in your tests
    def inventory_data
      {}
    end

    def inventory
      @inventory ||= Bolt::Inventory.create_version(inventory_data, config.transport, config.transports, plugins)
    end

    # Override in your tests
    def config
      @config ||= begin
        conf = Bolt::Config.default
        conf.modulepath = [modulepath].flatten
        conf
      end
    end

    def plugins
      @plugins ||= Bolt::Plugin.setup(config, pal)
    end

    def pal
      @pal ||= Bolt::PAL.new(config)
    end

    BoltSpec::Plans::MOCKED_ACTIONS.each do |action|
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

    # Does this belong here?
    def allow_out_message
      executor.stub_out_message.add_stub
    end
    alias allow_any_out_message allow_out_message

    def expect_out_message
      allow_out_message.expect_call
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
    # file uploads and downloads have a single destination and no arguments
    # def allow_file_upload(source_name)
    # def allow_file_download(source_name)
    #
    # Most of the information in commands is in the command string itself
    # we may need more flexible allows than just the name/command string
    # Only option params exist on a command.
    # def allow_command(command)
    # def allow_command_matching(command_regex)
    # def allow_command(&block)
  end
end
