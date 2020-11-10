# frozen_string_literal: true

module Bolt
  class Task
    module Run
      module_function

      # TODO: we should probably use a Bolt::Task for this
      def validate_params(task_signature, params)
        task_signature.runnable_with?(params) do |mismatch_message|
          raise Bolt::ValidationError, mismatch_message
        end || (raise Bolt::ValidationError, 'Task parameters do not match')

        unless Puppet::Pops::Types::TypeFactory.data.instance?(params)
          # generate a helpful error message about the type-mismatch between the type Data
          # and the actual type of use_args
          use_args_t = Puppet::Pops::Types::TypeCalculator.infer_set(params)
          desc = Puppet::Pops::Types::TypeMismatchDescriber.singleton.describe_mismatch(
            'Task parameters are not of type Data. run_task()',
            Puppet::Pops::Types::TypeFactory.data, use_args_t
          )
          raise Bolt::ValidationError, desc
        end
        nil
      end

      def wrap_sensitive(task, params)
        if (spec = task.metadata['parameters'])
          params.each_with_object({}) do |(param, val), wrapped|
            wrapped[param] = if spec.dig(param, 'sensitive')
                               Puppet::Pops::Types::PSensitiveType::Sensitive.new(val)
                             else
                               val
                             end
          end
        else
          params
        end
      end

      def run_task(task, targets, params, options, executor)
        if targets.empty?
          Bolt::ResultSet.new([])
        else
          result = executor.run_task_with_minimal_logging(targets, task, params, options)

          if !result.ok && !options[:catch_errors]
            raise Bolt::RunFailure.new(result, 'run_task', task.name)
          end
          result
        end
      end
    end
  end
end
