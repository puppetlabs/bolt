# frozen_string_literal: true

require 'json'
require 'logging'

module Bolt
  class Rerun
    def initialize(path, save_failures)
      @path = path
      @save_failures = save_failures
      @logger = Bolt::Logger.logger(self)
    end

    def data
      @data ||= Bolt::Util.read_json_file(@path, 'rerun')
      unless @data.is_a?(Array) && @data.all? { |r| r['target'] && r['status'] }
        raise Bolt::FileError.new("Missing data in rerun file: #{@path}", @path)
      end
      @data
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
      Bolt::Logger.warn_once('unwriteable_file', "Failed to save result to #{@path}: #{e.message}")
    end
  end
end
