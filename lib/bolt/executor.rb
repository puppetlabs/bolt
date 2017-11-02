require 'logger'
require 'concurrent'
require 'bolt/result'
require 'bolt/config'
require 'bolt/formatter'
require 'bolt/notifier'

module Bolt
  class Executor
    def initialize(config = Bolt::Config.new)
      @config = config
      @logger = Logger.new(config[:log_destination])
      @logger.progname = 'executor'
      @logger.level = config[:log_level]
      @logger.formatter = Bolt::Formatter.new
      @notifier = Bolt::Notifier.new
    end

    def from_uris(nodes)
      nodes.map do |node|
        Bolt::Node.from_uri(node, config: @config)
      end
    end

    def on(nodes, callback = nil)
      results = Concurrent::Map.new

      poolsize = [nodes.length, @config[:concurrency]].min
      pool = Concurrent::FixedThreadPool.new(poolsize)
      @logger.debug { "Started with #{poolsize} thread(s)" }

      nodes.map(&:class).uniq.each do |klass|
        klass.initialize_transport(@logger)
      end

      nodes.each { |node|
        pool.post do
          result =
            begin
              node.connect
              yield node
            rescue Bolt::Node::BaseError => ex
              Bolt::ErrorResult.new(ex.message, ex.issue_code, ex.kind)
            rescue StandardError => ex
              node.logger.error(ex)
              Bolt::ExceptionResult.new(ex)
            ensure
              node.disconnect
            end
          results[node] = result
          @notifier.notify(callback, node, result) if callback
          result
        end
      }
      pool.shutdown
      pool.wait_for_termination

      @notifier.shutdown

      results_to_hash(results)
    end

    def run_command(nodes, command)
      callback = block_given? ? Proc.new : nil

      on(nodes, callback) do |node|
        node.run_command(command)
      end
    end

    def run_script(nodes, script, arguments)
      callback = block_given? ? Proc.new : nil

      on(nodes, callback) do |node|
        node.run_script(script, arguments)
      end
    end

    def run_task(nodes, task, input_method, arguments)
      callback = block_given? ? Proc.new : nil

      on(nodes, callback) do |node|
        node.run_task(task, input_method, arguments)
      end
    end

    def file_upload(nodes, source, destination)
      callback = block_given? ? Proc.new : nil

      on(nodes, callback) do |node|
        node.upload(source, destination)
      end
    end

    private

    def results_to_hash(results)
      result_hash = {}
      results.each_pair { |k, v| result_hash[k] = v }
      result_hash
    end
  end
end
