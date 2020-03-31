# frozen_string_literal: true

require 'bolt/task'
require 'bolt/pal/issues'

# Query the state of resources on a list of targets using resource definitions in Bolt's modulepath.
# The results are returned as a list of hashes representing each resource.
#
# Requires the Puppet Agent be installed on the target, which can be accomplished with apply_prep
# or by directly running the `puppet_agent::install` task. In order to be able to reference types without
# string quoting (for example `get_resources($target, Package)` instead of `get_resources($target, 'Package')`),
# run the command `bolt puppetfile generate-types` to generate type references in `$Boldir/.resource_types`.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:get_resources) do
  # @param targets A pattern or array of patterns identifying a set of targets.
  # @param resources A resource type or instance, or an array of such.
  # @return A result set with a list of hashes representing each resource.
  # @example Collect resource states for packages and a file
  #   get_resources('target1,target2', [Package, File[/etc/puppetlabs]])
  dispatch :get_resources do
    param 'Boltlib::TargetSpec', :targets
    param 'Variant[String, Type[Resource], Array[Variant[String, Type[Resource]]]]', :resources
    return_type 'ResultSet'
  end

  def script_compiler
    @script_compiler ||= Puppet::Pal::ScriptCompiler.new(closure_scope.compiler)
  end

  def run_task(executor, targets, name, args = {})
    tasksig = script_compiler.task_signature(name)
    raise Bolt::Error.new("#{name} could not be found", 'bolt/get-resources') unless tasksig

    task = Bolt::Task.from_task_signature(tasksig)
    results = executor.run_task(targets, task, args)
    raise Bolt::RunFailure.new(results, 'run_task', task.name) unless results.ok?
    results
  end

  def get_resources(target_spec, resources)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'get_resources')
    end

    applicator = Puppet.lookup(:apply_executor)
    executor = Puppet.lookup(:bolt_executor)
    inventory = Puppet.lookup(:bolt_inventory)

    resources = [resources].flatten

    # Stringify resource types to pass to task
    resources.map! { |r| r.is_a?(String) ? r : r.to_s }

    resources.each do |resource|
      if resource !~ /^\w+$/ && resource !~ /^\w+\[.+\]$/
        raise Bolt::Error.new("#{resource} is not a valid resource type or type instance name", 'bolt/get-resources')
      end
    end

    executor.report_function_call(self.class.name)

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
