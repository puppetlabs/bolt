# frozen_string_literal: true

module Bolt
  module Transport
    class Orch < Base
      class Connection
        attr_reader :logger, :key

        CONTEXT_KEYS = Set.new(%i[plan_name description params sensitive]).freeze

        def self.get_key(opts)
          [
            opts['service-url'],
            opts['task-environment'],
            opts['token-file']
          ].join('-')
        end

        def initialize(opts, plan_context, logger)
          require 'addressable/uri'

          @logger = logger
          @key = self.class.get_key(opts)
          client_opts = opts.slice('token-file', 'cacert', 'job-poll-interval', 'job-poll-timeout', 'read-timeout')

          if opts['service-url']
            uri = Addressable::URI.parse(opts['service-url'])
            uri&.port ||= 8143
            client_opts['service-url'] = uri.to_s
          end

          client_opts['User-Agent'] = "Bolt/#{VERSION}"

          %w[token-file cacert].each do |f|
            client_opts[f] = File.expand_path(client_opts[f]) if client_opts[f]
          end
          logger.debug("Creating orchestrator client for #{client_opts}")
          @client = OrchestratorClient.new(client_opts, true)
          @plan_context = plan_context
          @plan_job = start_plan(@plan_context)
          logger.debug("Started plan #{@plan_job}")
          @environment = opts["task-environment"]
        end

        def start_plan(plan_context)
          if plan_context
            begin
              opts = plan_context.select { |k, _| CONTEXT_KEYS.include? k }
              opts[:params] = opts[:params].reject { |k, _| plan_context[:sensitive].include?(k) }
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
              result: plan_result.value || '',
              status: plan_result.status
            )
          end
        end

        def get_certnames(targets)
          targets.map { |t| t.host || t.name }
        end

        def build_request(targets, task, arguments, description = nil)
          body = { task: task.name,
                   environment: @environment,
                   noop: arguments['_noop'],
                   params: arguments.reject { |k, _| k.start_with?('_') },
                   scope: {
                     nodes: get_certnames(targets)
                   } }
          body[:description] = description if description
          body[:plan_job] = @plan_job if @plan_job
          body
        end

        def run_task(targets, task, arguments, options)
          body = build_request(targets, task, arguments, options[:description])
          @client.run_task(body)
        rescue OrchestratorClient::ApiError => e
          if e.data['kind'] == 'puppetlabs.orchestrator/plan-already-finished'
            @logger.debug("Retrying the task")
            # Instead of recursing, just retry once
            @plan_job = start_plan(@plan_context)
            # Rebuild the request with the new plan job ID
            body = build_request(targets, task, arguments, options[:description])
            @client.run_task(body)
          else
            raise e
          end
        end

        def query_inventory(targets)
          @client.post('inventory', nodes: get_certnames(targets))
        end
      end
    end
  end
end
