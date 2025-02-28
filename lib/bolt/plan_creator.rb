# frozen_string_literal: true

require_relative '../bolt/error'
require_relative '../bolt/logger'
require_relative '../bolt/module'
require_relative '../bolt/util'

module Bolt
  module PlanCreator
    def self.validate_plan_name(project, plan_name)
      if project.name.nil?
        raise Bolt::Error.new(
          "Project directory '#{project.path}' is not a named project. Unable to create " \
          "a project-level plan. To name a project, set the 'name' key in the 'bolt-project.yaml' " \
          "configuration file.",
          "bolt/unnamed-project-error"
        )
      end

      if plan_name !~ Bolt::Module::CONTENT_NAME_REGEX
        message = <<~MESSAGE.chomp
          Invalid plan name '#{plan_name}'. Plan names are composed of one or more name segments
          separated by double colons '::'.

          Each name segment must begin with a lowercase letter, and can only include lowercase
          letters, digits, and underscores.

          Examples of valid plan names:
              - #{project.name}
              - #{project.name}::my_plan
        MESSAGE

        raise Bolt::ValidationError, message
      end

      prefix, _, basename = segment_plan_name(plan_name)

      unless prefix == project.name
        message = "Incomplete plan name: A plan name must be prefixed with the name of the " \
          "project or module. Did you mean '#{project.name}::#{plan_name}'?"

        raise Bolt::ValidationError, message
      end

      %w[pp yaml].each do |ext|
        next unless (path = project.plans_path + "#{basename}.#{ext}").exist?
        raise Bolt::Error.new(
          "A plan with the name '#{plan_name}' already exists at '#{path}', nothing to do.",
          'bolt/existing-plan-error'
        )
      end
    end

    # Create a new plan from the plan templates based on which language the
    # user configured, and whether the plan wraps a script.
    #
    # @param plans_path [string] The path to the new plan
    # @param plan_name [string] The name of the new plan
    # @param is_puppet [boolean] Whether to create a Puppet language plan
    # @param script [string] A reference to a script for the new plan to run
    #
    def self.create_plan(plans_path, plan_name, is_puppet: false, script: nil)
      _, name_segments, basename = segment_plan_name(plan_name)
      dir_path = plans_path.join(*name_segments)

      begin
        FileUtils.mkdir_p(dir_path)
      rescue Errno::EEXIST => e
        raise Bolt::Error.new(
          "#{e.message}; unable to create plan directory '#{dir_path}'",
          'bolt/existing-file-error'
        )
      end

      type = is_puppet ? 'pp' : 'yaml'
      plan_path = dir_path + "#{basename}.#{type}"
      plan_template = if is_puppet && script
                        puppet_script_plan(plan_name, script)
                      elsif is_puppet
                        puppet_plan(plan_name)
                      elsif script
                        yaml_script_plan(script)
                      else
                        yaml_plan(plan_name)
                      end
      begin
        File.write(plan_path, plan_template)
      rescue Errno::EACCES => e
        raise Bolt::FileError.new(
          "#{e.message}; unable to create plan",
          plan_path
        )
      end

      { name: plan_name, path: plan_path }
    end

    def self.segment_plan_name(plan_name)
      prefix, *name_segments, basename = plan_name.split('::')

      # If the plan name is just the project name, then create an 'init' plan.
      # Otherwise, use the last name segment for the plan's filename.
      basename ||= 'init'

      [prefix, name_segments, basename]
    end

    # Template for a new simple YAML plan.
    #
    # @param plan_name [string] The name of the new plan
    #
    private_class_method def self.yaml_plan(plan_name)
      <<~YAML
        # This is the structure of a simple plan. To learn more about writing
        # YAML plans, see the documentation: http://pup.pt/bolt-yaml-plans

        # The description sets the description of the plan that will appear
        # in 'bolt plan show' output.
        description: A plan created with bolt plan new

        # The parameters key defines the parameters that can be passed to
        # the plan.
        parameters:
          targets:
            type: TargetSpec
            description: A list of targets to run actions on
            default: localhost

        # The steps key defines the actions the plan will take in order.
        steps:
          - message: Hello from #{plan_name}
          - name: command_step
            command: whoami
            targets: $targets

        # The return key sets the return value of the plan.
        return: $command_step
      YAML
    end

    # Template for a new YAML plan that runs a script.
    #
    # @param script [string] A reference to the script to run.
    #
    private_class_method def self.yaml_script_plan(script)
      <<~YAML
        # This is the structure of a simple plan. To learn more about writing
        # YAML plans, see the documentation: http://pup.pt/bolt-yaml-plans
        
        # The description sets the description of the plan that will appear
        # in 'bolt plan show' output.
        description: A plan created with bolt plan new

        # The parameters key defines the parameters that can be passed to
        # the plan.
        parameters:
          targets:
            type: TargetSpec
            description: A list of targets to run actions on

        # The steps key defines the actions the plan will take in order.
        steps:
          - name: run_script
            script: #{script}
            targets: $targets

        # The return key sets the return value of the plan.
        return: $run_script
      YAML
    end

    # Template for a new simple Puppet plan.
    #
    # @param plan_name [string] The name of the new plan
    #
    private_class_method def self.puppet_plan(plan_name)
      <<~PUPPET
        # This is the structure of a simple plan. To learn more about writing
        # Puppet plans, see the documentation: http://pup.pt/bolt-puppet-plans

        # The summary sets the description of the plan that will appear
        # in 'bolt plan show' output. Bolt uses puppet-strings to parse the
        # summary and parameters from the plan.
        # @summary A plan created with bolt plan new.
        # @param targets The targets to run on.
        plan #{plan_name} (
          TargetSpec $targets = "localhost"
        ) {
          out::message("Hello from #{plan_name}")
          $command_result = run_command('whoami', $targets)
          return $command_result
        }
      PUPPET
    end

    # Template for a new Puppet plan that only runs a script.
    #
    # @param plan_name [string] The name of the new plan
    # @param script [string] A reference to the script to run
    #
    private_class_method def self.puppet_script_plan(plan_name, script)
      <<~PUPPET
        # This is the structure of a simple plan. To learn more about writing
        # Puppet plans, see the documentation: http://pup.pt/bolt-puppet-plans

        # The summary sets the description of the plan that will appear
        # in 'bolt plan show' output. Bolt uses puppet-strings to parse the
        # summary and parameters from the plan.
        # @summary A plan created with bolt plan new.
        # @param targets The targets to run on.
        plan #{plan_name} (
          TargetSpec $targets
        ) {
          return run_script('#{script}', $targets)
        }
      PUPPET
    end
  end
end
