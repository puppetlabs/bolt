# frozen_string_literal: true

require 'json'
require 'bolt/error'
require 'bolt/result'

module Bolt
  class ApplyResult < Result
    def self.puppet_missing_error(result)
      error_hash = result.error_hash
      exit_code = error_hash['details']['exit_code'] if error_hash && error_hash['details']
      # If we get exit code 126 or 127 back, it means the shebang command wasn't found; Puppet isn't present
      if [126, 127].include?(exit_code)
        {
          'msg' => "Puppet is not installed on the target, please install it to enable 'apply'",
          'kind' => 'bolt/apply-error'
        }
      elsif exit_code == 1 &&
            (error_hash['msg'] =~ /Could not find executable 'ruby.exe'/ ||
             error_hash['msg'] =~ /The term 'ruby.exe' is not recognized as the name of a cmdlet/)
        # Windows does not have Ruby present
        {
          'msg' => "Puppet is not installed on the target in $env:ProgramFiles, please install it to enable 'apply'",
          'kind' => 'bolt/apply-error'
        }
      elsif exit_code == 1 && error_hash['msg'] =~ /cannot load such file -- puppet \(LoadError\)/
        # Windows uses a Ruby that doesn't have Puppet installed
        # TODO: fix so we don't find other Rubies, or point to a known issues URL for more info
        { 'msg' => 'Found a Ruby without Puppet present, please install Puppet ' \
                   "or remove Ruby from $env:Path to enable 'apply'",
          'kind' => 'bolt/apply-error' }
      end
    end

    def self.resource_error(result)
      if result.value['status'] == 'failed'
        resources = result.value['resource_statuses']
        failed = resources.select { |_, r| r['failed'] }.flat_map do |key, resource|
          resource['events'].select { |e| e['status'] == 'failure' }.map do |event|
            "\n  #{key}: #{event['message']}"
          end
        end

        { 'msg' => "Resources failed to apply for #{result.target.name}#{failed.join}",
          'kind' => 'bolt/resource-failure' }
      end
    end

    def self.from_task_result(result)
      if (puppet_missing = puppet_missing_error(result))
        new(result.target,
            error: puppet_missing,
            report: result.value.reject { |k| k == '_error' })
      elsif !result.ok?
        new(result.target, error: result.error_hash)
      elsif (resource_error = resource_error(result))
        new(result.target,
            error: resource_error,
            report: result.value.reject { |k| k == '_error' })
      else
        new(result.target, report: result.value)
      end
    end

    def initialize(target, error: nil, report: nil)
      @target = target
      @value = {}
      @type = 'apply'
      value['report'] = report if report
      value['_error'] = error if error
      value['_output'] = metrics_message if metrics_message
    end

    def event_metrics
      if (events = value.dig('report', 'metrics', 'resources', 'values'))
        events.each_with_object({}) { |ev, h| h[ev[0]] = ev[2] }
      end
    end

    # TODO: We've gotten requests for this type of logging but I'm not sure
    # what we shold do with it exactly.
    def log_events
      logger = Logging.logger[target.name]
      if (logs = value.dig('report', 'logs'))
        logs.each do |log|
          case log["level"]
          when 'err'
            logger.error(log['message'])
          when 'warn'
            logger.info(log['message'])
          when 'notice'
            logger.notice(log['message'])
          when 'info'
            logger.info(log['message'])
          else
            logger.debug(log["message"])
          end
        end
      end
    end

    def metrics_message
      if (metrics = event_metrics)
        changed = metrics['changed']
        failed = metrics['failed']
        skipped = metrics['skipped']
        unchanged = metrics['total'] - changed - failed - skipped
        noop = metrics['out_of_sync'] - changed - failed
        "changed: #{changed}, failed: #{failed}, unchanged: #{unchanged} skipped: #{skipped}, noop: #{noop}"
      end
    end

    def report
      @value['report']
    end
  end
end
