# frozen_string_literal: true

# This is a copy of the orchestrator transport connection, but without the
# 'start_plan' call in the init function which is handled by the orchestrator
# client
module Bolt
  module Transport
    class Api < Orch
      class Connection
        attr_reader :logger, :key

        CONTEXT_KEYS = Set.new(%i[plan_name description params]).freeze

        def self.get_key(opts)
          [
            opts['service-url'],
            opts['task-environment'],
            opts['token-file']
          ].join('-')
        end

        def initialize(opts, logger)
          @logger = logger
          @key = self.class.get_key(opts)
          client_keys = %w[service-url token-file cacert]
          client_opts = client_keys.each_with_object({}) do |k, acc|
            acc[k] = opts[k] if opts.include?(k)
          end
          client_opts['User-Agent'] = "Bolt/#{VERSION}"
          logger.debug("Creating orchestrator client for #{client_opts}")

          @client = OrchestratorClient.new(client_opts, true)
          @environment = opts["task-environment"]
        end

        def finish_plan(plan_result)
          if @plan_job
            @client.command.plan_finish(
              plan_job: @plan_job,
              result: plan_result.value || '',
              status: plan_result.status
            )
          end
        end

        def build_request(targets, task, arguments, description = nil)
          body = { task: task.name,
                   environment: @environment,
                   noop: arguments['_noop'],
                   params: arguments.reject { |k, _| k.start_with?('_') },
                   scope: {
                     nodes: targets.map(&:host)
                   } }
          body[:description] = description if description
          body[:plan_job] = @plan_job if @plan_job
          body
        end

        def run_task(targets, task, arguments, options)
          body = build_request(targets, task, arguments, options['_description'])
          @client.run_task(body)
        end

        def query_inventory(targets)
          @client.post('inventory', nodes: targets.map(&:host))
        end
      end
    end
  end
end
