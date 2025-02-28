# frozen_string_literal: true

require 'bolt/logger'
require 'bolt/task'

# Installs the `puppet-agent` package on targets if needed, then collects facts,
# including any custom facts found in Bolt's module path. The package is
# installed using either the configured plugin or the `task` plugin with the
# `puppet_agent::install` task.
#
# Agent installation will be skipped if the target includes the `puppet-agent`
# feature, either as a property of its transport (PCP) or by explicitly setting
# it as a feature in Bolt's inventory.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:apply_prep) do
  # @param targets A pattern or array of patterns identifying a set of targets.
  # @param options Options hash.
  # @option options [Boolean] _catch_errors Whether to catch raised errors.
  # @option options [Array] _required_modules An array of modules to sync to the target.
  # @option options [String] _run_as User to run as using privilege escalation.
  # @return [Bolt::ResultSet]
  # @example Prepare targets by name.
  #   apply_prep('target1,target2')
  dispatch :apply_prep do
    param 'Boltlib::TargetSpec', :targets
    optional_param 'Hash[String, Data]', :options
  end

  def apply_prep(target_spec, options = {})
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'apply_prep')
    end

    options = options.slice(*%w[_catch_errors _required_modules _run_as])
    targets = inventory.get_targets(target_spec)

    executor.report_function_call(self.class.name)

    executor.log_action('install puppet and gather facts', targets) do
      executor.without_default_logging do
        install_results = install_agents(targets, options)
        facts_results   = get_facts(install_results.ok_set.targets, options)

        Bolt::ResultSet.new(install_results.error_set.results + facts_results.results)
      end
    end
  end

  def applicator
    @applicator ||= Puppet.lookup(:apply_executor)
  end

  def executor
    @executor ||= Puppet.lookup(:bolt_executor)
  end

  def inventory
    @inventory ||= Puppet.lookup(:bolt_inventory)
  end

  # Runs a task. This method is called by the puppet_library hook.
  #
  def run_task(targets, task, args = {}, options = {})
    executor.run_task(targets, task, args, options)
  end

  # Returns true if the target has the puppet-agent feature defined, either from
  # inventory or transport.
  #
  private def agent?(target)
    inventory.features(target).include?('puppet-agent') ||
    executor.transport(target.transport).provided_features.include?('puppet-agent') ||
    target.remote?
  end

  # Generate the plugin tarball.
  #
  private def build_plugin_tarball(required_modules)
    if required_modules.any?
      Puppet.debug("Syncing only required modules: #{required_modules.join(',')}.")
    end

    tarball = applicator.build_plugin_tarball do |mod|
      next unless required_modules.empty? || required_modules.include?(mod.name)
      search_dirs = []
      search_dirs << mod.plugins if mod.plugins?
      search_dirs << mod.pluginfacts if mod.pluginfacts?
      search_dirs
    end

    Puppet::Pops::Types::PSensitiveType::Sensitive.new(tarball)
  end

  # Install the puppet-agent package on targets that need it.
  #
  private def install_agents(targets, options)
    results = []

    agent_targets, agentless_targets = targets.partition { |target| agent?(target) }

    agent_targets.each do |target|
      Puppet.debug("Puppet Agent feature declared for #{target}")
      results << Bolt::Result.new(target)
    end

    unless agentless_targets.empty?
      hooks, errors = get_hooks(agentless_targets, options)
      hook_results  = run_hooks(hooks)

      hook_results.each do |result|
        next unless result.ok?
        inventory.set_feature(result.target, 'puppet-agent')
      end

      results.concat(hook_results).concat(errors)
    end

    Bolt::ResultSet.new(results).tap do |resultset|
      unless resultset.ok? || options['_catch_errors']
        raise Bolt::RunFailure.new(resultset.error_set, 'apply_prep')
      end
    end
  end

  # Retrieve facts from each target and add them to inventory.
  #
  private def get_facts(targets, options)
    return Bolt::ResultSet.new([]) unless targets.any?

    task    = applicator.custom_facts_task
    args    = { 'plugins' => build_plugin_tarball(options.delete('_required_modules').to_a) }
    results = run_task(targets, task, args, options)

    unless results.ok? || options['_catch_errors']
      raise Bolt::RunFailure.new(results, 'run_task', task.name)
    end

    results.each do |result|
      next unless result.ok?

      if unsupported_puppet?(result['clientversion'])
        Bolt::Logger.deprecate(
          "unsupported_puppet",
          "Detected unsupported Puppet agent version #{result['clientversion']} on target " \
          "#{result.target}. Bolt supports Puppet agent 6.0.0 and higher."
        )
      end

      inventory.add_facts(result.target, result.value)
    end

    results
  end

  # Return a list of targets and their puppet_library hooks.
  #
  private def get_hooks(targets, options)
    hooks  = []
    errors = []

    targets.each do |target|
      plugin_opts = target.plugin_hooks.fetch('puppet_library').dup
      plugin_name = plugin_opts.delete('plugin')
      hook        = inventory.plugins.get_hook(plugin_name, :puppet_library)

      hooks << { 'target' => target,
                 'proc'   => hook.call(plugin_opts.merge(options), target, self) }
    rescue StandardError => e
      errors << Bolt::Result.from_exception(target, e)
    end

    [hooks, errors]
  end

  # Runs the puppet_library hook for each target, returning the result
  # of each.
  #
  private def run_hooks(hooks)
    require 'concurrent'
    pool = Concurrent::ThreadPoolExecutor.new

    futures = hooks.map do |hook|
      Concurrent::Future.execute(executor: pool) do
        hook['proc'].call
      end
    end

    futures.zip(hooks).map do |future, hook|
      future.value || Bolt::Result.from_exception(hook['target'], future.reason)
    end
  end

  # Returns true if the client's major version is < 6.
  #
  private def unsupported_puppet?(client_version)
    if client_version.nil?
      false
    else
      begin
        Integer(client_version.split('.').first) < 6
      rescue StandardError
        false
      end
    end
  end
end
