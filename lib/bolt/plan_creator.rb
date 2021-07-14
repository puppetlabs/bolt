# frozen_string_literal: true

require 'bolt/error'
require 'bolt/logger'
require 'bolt/module'
require 'bolt/util'

module Bolt
  module PlanCreator
    def self.validate_input(project, plan_name)
      if project.name.nil?
        raise Bolt::Error.new(
          "Project directory '#{project.path}' is not a named project. Unable to create "\
          "a project-level plan. To name a project, set the 'name' key in the 'bolt-project.yaml' "\
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
        message = "Incomplete plan name: A plan name must be prefixed with the name of the "\
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

    def self.create_plan(plans_path, plan_name, is_puppet)
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
      plan_template = is_puppet ? puppet_plan(plan_name) : yaml_plan(plan_name)

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

    def self.yaml_plan(plan_name)
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

    def self.puppet_plan(plan_name)
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
  end
end
