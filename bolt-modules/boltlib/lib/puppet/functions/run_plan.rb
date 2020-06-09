# frozen_string_literal: true

require 'bolt/error'

# Runs the `plan` referenced by its name. A plan is autoloaded from `$MODULEROOT/plans`.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:run_plan, Puppet::Functions::InternalFunction) do
  # Run a plan
  # @param plan_name The plan to run.
  # @param args A hash of arguments to the plan. Can also include additional options.
  # @option args [Boolean] _catch_errors Whether to catch raised errors.
  # @option args [String] _run_as User to run as using privilege escalation.
  # @return [PlanResult] The result of running the plan. Undef if plan does not explicitly return results.
  # @example Run a plan
  #   run_plan('canary', 'command' => 'false', 'targets' => $targets, '_catch_errors' => true)
  dispatch :run_plan do
    scope_param
    param 'String', :plan_name
    optional_param 'Hash', :args
    return_type 'Boltlib::PlanResult'
  end

  # Run a plan, specifying `$nodes` or `$targets` as a positional argument.
  #
  # > **Note:** When running a plan with both a `$nodes` and `$targets` parameter, and using the second
  # positional argument, the plan will fail.
  #
  # @param plan_name The plan to run.
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param args A hash of arguments to the plan. Can also include additional options.
  # @option args [Boolean] _catch_errors Whether to catch raised errors.
  # @option args [String] _run_as User to run as using privilege escalation.
  # @return [PlanResult] The result of running the plan. Undef if plan does not explicitly return results.
  # @example Run a plan
  #   run_plan('canary', $targets, 'command' => 'false')
  dispatch :run_plan_with_targetspec do
    scope_param
    param 'String', :plan_name
    param 'Boltlib::TargetSpec', :targets
    optional_param 'Hash', :args
    return_type 'Boltlib::PlanResult'
  end

  def run_plan_with_targetspec(scope, plan_name, targets, args = {})
    run_inner_plan(scope, plan_name, targets, args)
  end

  def run_plan(scope, plan_name, args = {})
    run_inner_plan(scope, plan_name, nil, args)
  end

  def run_inner_plan(scope, plan_name, targets, args = {})
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'run_plan')
    end

    executor = Puppet.lookup(:bolt_executor)

    options, params = args.partition { |k, _v| k.start_with?('_') }.map(&:to_h)
    options = options.transform_keys { |k| k.sub(/^_/, '').to_sym }

    # Bolt calls this function internally to trigger plans from the CLI. We
    # don't want to count those invocations.
    unless options[:bolt_api_call]
      executor.report_function_call(self.class.name)
    end

    # Report bundled content, this should capture plans run from both CLI and Plans
    executor.report_bundled_content('Plan', plan_name)

    loaders = closure_scope.compiler.loaders
    # The perspective of the environment is wanted here (for now) to not have to
    # require modules to have dependencies defined in meta data.
    loader = loaders.private_environment_loader

    # TODO: Why would we not have a private_environment_loader?
    unless loader && (func = loader.load(:plan, plan_name))
      raise Bolt::Error.unknown_plan(plan_name)
    end

    if (run_as = options[:run_as])
      old_run_as = executor.run_as
      executor.run_as = run_as
    end

    closure = func.class.dispatcher.dispatchers[0]
    if closure.model.is_a?(Bolt::PAL::YamlPlan)
      executor.report_yaml_plan(closure.model.body)
    end

    # If a TargetSpec parameter is passed, ensure it is in inventory
    inventory = Puppet.lookup(:bolt_inventory)

    param_types = closure.parameters.each_with_object({}) do |param, param_acc|
      param_acc[param.name] = extract_parameter_types(param.type_expr)&.flatten
    end

    targets_to_param(targets, params, param_types) if targets

    if inventory.version > 1
      params.each do |param, value|
        # Note the safe lookup operator is needed to handle case where a parameter is passed to a
        # plan that the plan is not expecting
        if param_types[param]&.include?('TargetSpec') || param_types[param]&.include?('Boltlib::TargetSpec')
          inventory.get_targets(value)
        end
      end
    end

    # Wrap Sensitive parameters for plans that are run from the CLI, as it's impossible to pass
    # a Sensitive value that way. We don't do this for plans run from the run_plan function, as
    # it can receive Sensitive values as arguments.
    # This should only happen after expanding target params, otherwise things will blow up if
    # the targets are wrapped as Sensitive. Hopefully nobody does that, though...
    if options[:bolt_api_call]
      params = wrap_sensitive_parameters(params, closure.parameters)
    end

    # wrap plan execution in logging messages
    executor.log_plan(plan_name) do
      result = nil
      begin
        # If the plan does not throw :return by calling the return function it's result is
        # undef/nil
        result = catch(:return) do
          scope.with_global_scope do |global_scope|
            executor.run_plan(global_scope, closure, params)
          end
          nil
        end&.value
        # Validate the result is a PlanResult
        unless Puppet::Pops::Types::TypeParser.singleton.parse('Boltlib::PlanResult').instance?(result)
          raise Bolt::InvalidPlanResult.new(plan_name, result.to_s)
        end

        result
      rescue Puppet::PreformattedError => e
        if options[:catch_errors] && e.cause.is_a?(Bolt::Error)
          result = e.cause.to_puppet_error
        else
          raise e
        end
      ensure
        if run_as
          executor.run_as = old_run_as
        end
      end

      result
    end
  end

  # Recursively examine the type_expr to build a list of types
  def extract_parameter_types(type_expr)
    # No type
    if type_expr.nil?
      []
    # Multiple types to extract (ex. Variant[TargetSpec, String])
    elsif defined?(type_expr.keys)
      type_expr.keys.flat_map { |param| extract_parameter_types(param) }
    # Store cased value
    elsif defined?(type_expr.cased_value)
      [type_expr.cased_value]
    # Type alias, able to resolve alias
    elsif defined?(type_expr.resolved_type.name)
      [type_expr.resolved_type.name]
    # Nested type alias, recurse
    elsif defined?(type_expr.type)
      extract_parameter_types(type_expr.type)
    # Array conatins alias types
    elsif defined?(type_expr.types)
      type_expr.types.flat_map { |param| extract_parameter_types(param) }
    # Each element can be handled by a resolver above
    elsif defined?(type_expr.element_type)
      extract_parameter_types(type_expr.element_type)
    end
  end

  # Wrap any Sensitive parameters in the Sensitive wrapper type, unless they are already
  # wrapped as Sensitive. This will also raise a helpful warning if the type expression
  # is a complex data type using Sensitive, as we don't handle those cases.
  def wrap_sensitive_parameters(params, param_models)
    models = param_models.each_with_object({}) { |param, acc| acc[param.name] = param }

    params.each_with_object({}) do |(name, value), acc|
      model = models[name]

      # Parameters passed to a plan that the plan is not expecting don't have a model,
      # so keep the parameter as-is.
      if model.nil?
        acc[name] = value
      elsif sensitive_type?(model.type_expr)
        acc[name] = Puppet::Pops::Types::PSensitiveType::Sensitive.new(value)
      else
        if model.type_expr.to_s.include?('Sensitive')
          # Include the location for regular plans. YAML plans don't have this info, so
          # the location will be suppressed.
          file = defined?(model.file) ? model.file : :default
          line = defined?(model.line) ? model.line : :default

          Puppet.warn_once(
            'unsupported_sensitive_type',
            name,
            "Parameter '#{name}' is a complex type using Sensitive, unable to automatically wrap as Sensitive",
            file,
            line
          )
        end

        acc[name] = value
      end
    end
  end

  # Whether the type is a supported Sensitive type. We only support wrapping parameterized
  # and non-parameterized Sensitive types (e.g. Sensitive, Sensitive[String])
  def sensitive_type?(type_expr)
    # Parameterized Sensitive type (e.g. Sensitive[String])
    # left_expr is defined whenever the type is parameterized. If this is a parameterized
    # Sensitive type, then we check the cased_value, which is the stringified version of
    # the left expression's type.
    (defined?(type_expr.left_expr) && type_expr.left_expr.cased_value == 'Sensitive') ||
      # Non-parameterized Sensitive type (Sensitive)
      # cased_value is defined whenever the type is non-parameterized. If the type expression
      # defines cased_value, then this is a simple type and we just need to check that it's
      # Sensitive.
      (defined?(type_expr.cased_value) && type_expr.cased_value == 'Sensitive') ||
      # Sensitive type from YAML plans
      # Type expressions from YAML plans are a different class than those from regular plans.
      # As long as the type expression is PSensitiveType we can be sure that the type is
      # either a parameterized or non-parameterized Sensitive type.
      type_expr.instance_of?(Puppet::Pops::Types::PSensitiveType)
  end

  def targets_to_param(targets, params, param_types)
    nodes_param = param_types.include?('nodes')
    targets_param = param_types['targets']&.any? { |p| p.match?(/TargetSpec/) }

    # Both a 'TargetSpec $nodes' and 'TargetSpec $targets' parameter are present in the plan
    if nodes_param && targets_param
      raise ArgumentError,
            "A plan with both a $nodes and $targets parameter cannot have either parameter specified " \
            "as the second positional argument to run_plan()."
    end

    # Always populate a $nodes parameter over $targets
    if nodes_param
      if params['nodes']
        raise ArgumentError,
              "A plan's 'nodes' parameter may be specified as the second positional argument to " \
              "run_plan(), but in that case 'nodes' must not be specified in the named arguments " \
              "hash."
      end
      params['nodes'] = targets
    # If there is only a $targets parameter, then populate it
    elsif targets_param
      if params['targets']
        raise ArgumentError,
              "A plan's 'targets' parameter may be specified as the second positional argument to " \
              "run_plan(), but in that case 'targets' must not be specified in the named arguments " \
              "hash."
      end
      params['targets'] = targets
    # If a plan has neither parameter, just fall back to $nodes
    else
      params['nodes'] = targets
    end
  end
end
