# frozen_string_literal: true

require 'bolt/task'
require 'bolt/pal/issues'

# Installs the `puppet-agent` package on targets if needed, then collects facts,
# including any custom facts found in Bolt's modulepath. The package is
# installed using either the configured plugin or the `task` plugin with the
# `puppet_agent::install` task.
#
# Agent installation will be skipped if the target includes the `puppet-agent` feature, either as a
# property of its transport (PCP) or by explicitly setting it as a feature in Bolt's inventory.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:apply_prep) do
  # @param targets A pattern or array of patterns identifying a set of targets.
  # @example Prepare targets by name.
  #   apply_prep('target1,target2')
  dispatch :apply_prep do
    param 'Boltlib::TargetSpec', :targets
  end

  def script_compiler
    @script_compiler ||= Puppet::Pal::ScriptCompiler.new(closure_scope.compiler)
  end

  def inventory
    @inventory ||= Puppet.lookup(:bolt_inventory)
  end

  def get_task(name, params = {})
    tasksig = script_compiler.task_signature(name)
    raise Bolt::Error.new("Task '#{name}' could not be found", 'bolt/apply-prep') unless tasksig

    errors = []
    unless tasksig.runnable_with?(params) { |msg| errors << msg }
      # This relies on runnable with printing a partial message before the first real error
      raise Bolt::ValidationError, "Invalid parameters for #{errors.join("\n")}"
    end

    Bolt::Task.from_task_signature(tasksig)
  end

  # rubocop:disable Naming/AccessorMethodName
  def set_agent_feature(target)
    inventory.set_feature(target, 'puppet-agent')
  end
  # rubocop:enable Naming/AccessorMethodName

  def run_task(targets, task, args = {}, options = {})
    executor.run_task(targets, task, args, options)
  end

  # Returns true if the target has the puppet-agent feature defined, either from inventory or transport.
  def agent?(target, executor, inventory)
    inventory.features(target).include?('puppet-agent') ||
      executor.transport(target.transport).provided_features.include?('puppet-agent') || target.remote?
  end

  def executor
    @executor ||= Puppet.lookup(:bolt_executor)
  end

  def apply_prep(target_spec)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'apply_prep')
    end

    applicator = Puppet.lookup(:apply_executor)

    executor.report_function_call(self.class.name)

    targets = inventory.get_targets(target_spec)

    executor.log_action('install puppet and gather facts', targets) do
      executor.without_default_logging do
        # Skip targets that include the puppet-agent feature, as we know an agent will be available.
        agent_targets, need_install_targets = targets.partition { |target| agent?(target, executor, inventory) }
        agent_targets.each { |target| Puppet.debug "Puppet Agent feature declared for #{target.name}" }
        unless need_install_targets.empty?
          # lazy-load expensive gem code
          require 'concurrent'
          pool = Concurrent::ThreadPoolExecutor.new

          hooks = need_install_targets.map do |t|
            opts = t.plugin_hooks&.fetch('puppet_library').dup
            plugin_name = opts.delete('plugin')
            hook = inventory.plugins.get_hook(plugin_name, :puppet_library)
            { 'target' => t,
              'hook_proc' => hook.call(opts, t, self) }
          rescue StandardError => e
            Bolt::Result.from_exception(t, e)
          end

          hook_errors, ok_hooks = hooks.partition { |h| h.is_a?(Bolt::Result) }

          futures = ok_hooks.map do |hash|
            Concurrent::Future.execute(executor: pool) do
              hash['hook_proc'].call
            end
          end

          results = futures.zip(ok_hooks).map do |f, hash|
            f.value || Bolt::Result.from_exception(hash['target'], f.reason)
          end
          set = Bolt::ResultSet.new(results + hook_errors)
          raise Bolt::RunFailure.new(set.error_set, 'apply_prep') unless set.ok

          need_install_targets.each { |target| set_agent_feature(target) }
        end

        # Gather facts, including custom facts
        plugins = applicator.build_plugin_tarball do |mod|
          search_dirs = []
          search_dirs << mod.plugins if mod.plugins?
          search_dirs << mod.pluginfacts if mod.pluginfacts?
          search_dirs
        end

        task = applicator.custom_facts_task
        arguments = { 'plugins' => Puppet::Pops::Types::PSensitiveType::Sensitive.new(plugins) }
        results = executor.run_task(targets, task, arguments)
        # TODO: Standardize RunFailure type with error above
        raise Bolt::RunFailure.new(results, 'run_task', task.name) unless results.ok?

        results.each do |result|
          inventory.add_facts(result.target, result.value)
        end
      end
    end

    # Return nothing
    nil
  end
end
