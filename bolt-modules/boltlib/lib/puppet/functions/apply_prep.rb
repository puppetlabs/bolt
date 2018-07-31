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

    targets = inventory.get_targets(target_spec)

    # Ensure Puppet is installed
    versions = call_function(:run_task, 'puppet_agent::version', targets)
    need_install, installed = versions.partition { |r| r.message.chomp.empty? }
    installed.each do |r|
      Puppet.info "Puppet Agent #{r.message.chomp} installed on #{r.target.name}"
    end
    unless need_install.empty?
      call_function(:run_task, 'puppet_agent::install', need_install.map(&:target))
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
    raise Bolt::RunFailure.new(results, 'run_task', task.name) unless results.ok

    results.each do |result|
      inventory.add_facts(result.target, result.value)
    end
  end
end
