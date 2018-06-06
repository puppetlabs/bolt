# frozen_string_literal: true

module Bolt
  module Transport
    class Orch < Base
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

        def initialize(opts, plan_context, logger)
          @logger = logger
          @key = self.class.get_key(opts)
          client_keys = %w[service-url token-file cacert]
          client_opts = client_keys.each_with_object({}) do |k, acc|
            acc[k] = opts[k] if opts.include?(k)
          end
          client_opts['User-Agent'] = "Bolt/#{VERSION}"
          logger.debug("Creating orchestrator client for #{client_opts}")

          @client = OrchestratorClient.new(client_opts, true)
          @plan_job = start_plan(plan_context)
          @environment = opts["task-environment"]
        end

        def start_plan(plan_context)
          if plan_context
            begin
              opts = plan_context.select { |k, _| CONTEXT_KEYS.include? k }
              @client.command.plan_start(opts)['name']
            rescue OrchestratorClient::ApiError => e
              if e.code == '404'
                @logger.debug("Orchestrator #{key} does not support plans")
              else
                @logger.error("Failed to start a plan with orchestrator #{key}: #{e.message}")
              end
              nil
            end
          end
        end

        def finish_plan(plan_result)
          if @plan_job
            @client.command.plan_finish(
              plan_job: @plan_job,
              result: plan_result.value,
              status: plan_result.status
            )
          end
        end

        def build_request(targets, task, arguments, description = nil)
          body = { task: task.name,
                   environment: @environment,
                   noop: arguments['_noop'],
                   params: arguments.reject { |k, _| k == '_noop' },
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
      end
    end
  end
end
