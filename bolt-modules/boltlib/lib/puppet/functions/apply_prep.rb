# frozen_string_literal: true

require 'bolt/task'

# Installs the puppet-agent package on targets if needed then collects facts, including any custom
# facts found in Bolt's modulepath.
#
# Agent detection will be skipped if the target includes the 'puppet-agent' feature, either as a
# property of its transport (PCP) or by explicitly setting it as a feature in Bolt's inventory.
#
# If no agent is detected on the target using the 'puppet_agent::version' task, it's installed
# using 'puppet_agent::install' and the puppet service is stopped/disabled using the 'service' task.
#
# **NOTE:** Not available in apply block
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

  def run_task(executor, targets, name, args = {})
    tasksig = script_compiler.task_signature(name)
    raise Bolt::Error.new("#{name} could not be found", 'bolt/apply-prep') unless tasksig

    task = Bolt::Task.new(tasksig.task_hash)
    results = executor.run_task(targets, task, args)
    raise Bolt::RunFailure.new(results, 'run_task', task.name) unless results.ok?
    results
  end

  # Returns true if the target has the puppet-agent feature defined, either from inventory or transport.
  def agent?(target, executor, inventory)
    inventory.features(target).include?('puppet-agent') ||
      executor.transport(target.transport).provided_features.include?('puppet-agent') || target.remote?
  end

  def apply_prep(target_spec)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'apply_prep')
    end

    applicator = Puppet.lookup(:apply_executor)
    executor = Puppet.lookup(:bolt_executor)
    inventory = Puppet.lookup(:bolt_inventory)

    executor.report_function_call('apply_prep')

    targets = inventory.get_targets(target_spec)

    executor.log_action('install puppet and gather facts', targets) do
      executor.without_default_logging do
        # Skip targets that include the puppet-agent feature, as we know an agent will be available.
        agent_targets, unknown_targets = targets.partition { |target| agent?(target, executor, inventory) }
        agent_targets.each { |target| Puppet.debug "Puppet Agent feature declared for #{target.name}" }
        unless unknown_targets.empty?
          # Ensure Puppet is installed
          versions = run_task(executor, unknown_targets, 'puppet_agent::version')
          need_install, installed = versions.partition { |r| r['version'].nil? }
          installed.each do |r|
            Puppet.debug "Puppet Agent #{r['version']} installed on #{r.target.name}"
            inventory.set_feature(r.target, 'puppet-agent')
          end

          unless need_install.empty?
            need_install_targets = need_install.map(&:target)
            run_task(executor, need_install_targets, 'puppet_agent::install')
            # Service task works best when targets have puppet-agent feature
            need_install_targets.each { |target| inventory.set_feature(target, 'puppet-agent') }
            # Ensure the Puppet service is stopped after new install
            run_task(executor, need_install_targets, 'service', 'action' => 'stop', 'name' => 'puppet')
            run_task(executor, need_install_targets, 'service', 'action' => 'disable', 'name' => 'puppet')
          end
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
