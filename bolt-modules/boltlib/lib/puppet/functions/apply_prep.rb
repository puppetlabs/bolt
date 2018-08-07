# frozen_string_literal: true

require 'fileutils'

Puppet::Functions.create_function(:apply_prep) do
  dispatch :apply_prep do
    param 'Boltlib::TargetSpec', :targets
  end

  def apply_prep(target_spec)
    applicator = Puppet.lookup(:apply_executor) { nil }
    executor = Puppet.lookup(:bolt_executor) { nil }
    inventory = Puppet.lookup(:bolt_inventory) { nil }
    unless applicator && executor && inventory && Puppet.features.bolt?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('apply_prep')
      )
    end

    executor.report_function_call('apply_prep')

    targets = inventory.get_targets(target_spec)

    executor.log_action('install puppet and gather facts', targets) do
      executor.without_default_logging do
        script_compiler = Puppet::Pal::ScriptCompiler.new(closure_scope.compiler)

        # Ensure Puppet is installed
        version_task = script_compiler.task_signature('puppet_agent::version')
        raise Bolt::Error.new('puppet_agent::version could not be found', 'bolt/apply-prep') unless version_task
        versions = executor.run_task(targets, version_task.task, {})
        raise Bolt::RunFailure.new(versions, 'run_task', version_task.name) unless versions.ok?
        need_install, installed = versions.partition { |r| r['version'].nil? }
        installed.each do |r|
          Puppet.info "Puppet Agent #{r['version']} installed on #{r.target.name}"
        end

        unless need_install.empty?
          install_task = script_compiler.task_signature('puppet_agent::install')
          raise Bolt::Error.new('puppet_agent::install could not be found', 'bolt/apply-prep') unless install_task
          installed = executor.run_task(need_install.map(&:target), install_task.task, {})
          raise Bolt::RunFailure.new(installed, 'run_task', install_task.name) unless installed.ok?
        end
        targets.each { |target| inventory.set_feature(target, 'puppet-agent') }

        # Gather facts, including custom facts
        plugins = applicator.build_plugin_tarball do |mod|
          search_dirs = []
          search_dirs << mod.plugins if mod.plugins?
          search_dirs << mod.pluginfacts if mod.pluginfacts?
          search_dirs
        end

        task = applicator.custom_facts_task
        results = executor.run_task(targets, task, 'plugins' => plugins)
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
