# frozen_string_literal: true

require 'json'
require 'logging'

module Bolt
  class Rerun
    def initialize(path, save_failures)
      @path = path
      @save_failures = save_failures
      @logger = Logging.logger[self]
    end

    def data
      @data ||= JSON.parse(File.read(@path))
      unless @data.is_a?(Array) && @data.all? { |r| r['target'] && r['status'] }
        raise Bolt::FileError.new("Missing data in rerun file: #{@path}", @path)
      end
      @data
    rescue JSON::ParserError
      raise Bolt::FileError.new("Could not parse rerun file: #{@path}", @path)
    rescue IOError, SystemCallError
      raise Bolt::FileError.new("Could not read rerun file: #{@path}", @path)
    end

    def get_targets(filter)
      filtered = case filter
                 when 'all'
                   data
                 when 'failure'
                   data.select { |result| result['status'] == 'failure' }
                 when 'success'
                   data.select { |result| result['status'] == 'success' }
                 else
                   raise Bolt::CLIError, "Unexpected option #{filter} for '--retry'"
                 end
      filtered.map { |result| result['target'] }
    end

    def update(result_set)
      unless @save_failures == false
        if result_set.is_a?(Bolt::PlanResult)
          result_set = result_set.value
          result_set = result_set.result_set if result_set.is_a?(Bolt::RunFailure)
        end

        if result_set.is_a?(Bolt::ResultSet)
          data = result_set.map { |res| { target: res.target.name, status: res.status } }
          FileUtils.mkdir_p(File.dirname(@path))
          File.write(@path, data.to_json)
        elsif File.exist?(@path)
          FileUtils.rm(@path)
        end
      end
    rescue StandardError => e
      @logger.warn("Failed to save result to #{@path}: #{e.message}")
    end
  end
end
