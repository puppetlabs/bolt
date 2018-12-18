# frozen_string_literal: true

require 'bolt/task'

# Query the state of resources on a list of targets using resource definitions in Bolt's modulepath.
# The results are returned as a list of hashes representing each resource.
#
# Requires the Puppet Agent be installed on the target, which can be accomplished with apply_prep
# or by directly running the puppet_agent::install task.
Puppet::Functions.create_function(:get_resources) do
  # @param targets A pattern or array of patterns identifying a set of targets.
  # @param resources A resource type or instance, or an array of such.
  # @example Collect resource states for packages and a file
  #   get_resources('target1,target2', [Package, File[/etc/puppetlabs]])
  dispatch :get_resources do
    param 'Boltlib::TargetSpec', :targets
    param 'Variant[String, Resource, Array[Variant[String, Resource]]]', :resources
  end

  def script_compiler
    @script_compiler ||= Puppet::Pal::ScriptCompiler.new(closure_scope.compiler)
  end

  def run_task(executor, targets, name, args = {})
    tasksig = script_compiler.task_signature(name)
    raise Bolt::Error.new("#{name} could not be found", 'bolt/get-resources') unless tasksig

    task = Bolt::Task.new(tasksig.task_hash)
    results = executor.run_task(targets, task, args)
    raise Bolt::RunFailure.new(results, 'run_task', task.name) unless results.ok?
    results
  end

  def get_resources(target_spec, resources)
    applicator = Puppet.lookup(:apply_executor) { nil }
    executor = Puppet.lookup(:bolt_executor) { nil }
    inventory = Puppet.lookup(:bolt_inventory) { nil }
    unless applicator && executor && inventory && Puppet.features.bolt?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('get_resources')
      )
    end

    resources = [resources].flatten
    resources.each do |resource|
      if resource !~ /^\w+$/ && resource !~ /^\w+\[.+\]$/
        raise Bolt::Error.new("#{resource} is not a valid resource type or type instance name", 'bolt/get-resources')
      end
    end

    executor.report_function_call('get_resources')

    targets = inventory.get_targets(target_spec)

    executor.log_action('gather resources', targets) do
      executor.without_default_logging do
        # Gather facts, including custom facts
        plugins = applicator.build_plugin_tarball do |mod|
          search_dirs = []
          search_dirs << mod.plugins if mod.plugins?
          search_dirs << mod.pluginfacts if mod.pluginfacts?
          search_dirs
        end

        task = applicator.query_resources_task
        arguments = {
          'resources' => resources,
          'plugins' => Puppet::Pops::Types::PSensitiveType::Sensitive.new(plugins)
        }
        results = executor.run_task(targets, task, arguments)
        raise Bolt::RunFailure.new(results, 'run_task', task.name) unless results.ok?
        results
      end
    end
  end
end
