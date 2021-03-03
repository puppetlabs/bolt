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
          'msg' => "Puppet was not found on the target or in $env:ProgramFiles, please install it to enable 'apply'",
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

    def self.invalid_report_error(result)
      # These are the keys ApplyResult methods rely on.
      expected_report_keys = %w[metrics resource_statuses status]
      missing_keys = expected_report_keys.reject { |k| result.value.include?(k) }

      unless missing_keys.empty?
        if result['_output']
          # rubocop:disable Layout/LineLength
          msg = "Report result contains an '_output' key. Catalog application might have printed extraneous output to stdout: #{result['_output']}"
          # rubocop:enable Layout/LineLength
        else
          msg = "Report did not contain all expected keys missing: #{missing_keys.join(', ')}"
        end

        { 'msg' => msg,
          'kind' => 'bolt/invalid-report' }
      end
    end

    def self.from_task_result(result)
      if (puppet_missing = puppet_missing_error(result))
        new(result.target,
            error: puppet_missing,
            report: result.value.reject { |k| k == '_error' })
      elsif !result.ok?
        new(result.target, error: result.error_hash)
      elsif (invalid_report = invalid_report_error(result))
        new(result.target,
            error: invalid_report,
            report: result.value.reject { |k| %w[_error _output].include?(k) })
      elsif (resource_error = resource_error(result))
        new(result.target,
            error: resource_error,
            report: result.value.reject { |k| k == '_error' })
      else
        new(result.target, report: result.value)
      end
    end

    # Other pcore methods are inherited from Result
    def _pcore_init_hash
      { 'target' => @target,
        'error' => value['_error'],
        'report' => value['report'] }
    end

    def initialize(target, error: nil, report: nil)
      @target = target
      @value = {}
      @action = 'apply'
      @value['report'] = report if report
      @value['_error'] = error if error
      @value['_output'] = metrics_message if metrics_message
    end

    def event_metrics
      if (events = value.dig('report', 'metrics', 'resources', 'values'))
        events.each_with_object({}) { |ev, h| h[ev[0]] = ev[2] }
      end
    end

    def logs
      value.dig('report', 'logs') || []
    end

    # Return only log messages associated with resources
    def resource_logs
      logs.reject { |log| log['source'] == 'Puppet' }
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

    def generic_value
      {}
    end
  end
end
