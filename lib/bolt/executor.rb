require 'logger'
require 'concurrent'
require 'bolt/result'
require 'bolt/config'
require 'bolt/formatter'
require 'bolt/notifier'

module Bolt
  class Executor
    attr_reader :noop

    def initialize(config = Bolt::Config.new, noop = nil)
      @config = config
      @logger = Logger.new(config[:log_destination])
      @logger.progname = 'executor'
      @logger.level = config[:log_level]
      @logger.formatter = Bolt::Formatter.new
      @noop = noop
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
              @notifier.notify(callback, node, type: :node_start) if callback
              node.connect
              yield node
            rescue StandardError => ex
              Bolt::Result.from_exception(ex)
            ensure
              begin
                node.disconnect
              rescue StandardError => ex
                @logger.info("Failed to close connection to #{node.uri} : #{ex.message}")
              end
            end
          results[node] = result
          if callback
            @notifier.notify(callback, node, type: :node_result, result: result)
          end
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
