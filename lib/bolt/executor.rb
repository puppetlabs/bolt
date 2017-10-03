require 'concurrent'
require 'bolt/result'

module Bolt
  class Executor
    def self.from_uris(uris)
      new(uris.map { |uri| Bolt::Node.from_uri(uri) })
    end

    def initialize(nodes)
      @nodes = nodes
    end

    def on_each
      results = Concurrent::Map.new

      pool = Concurrent::FixedThreadPool.new(5)
      @nodes.each { |node|
        pool.post do
          results[node] =
            begin
              node.connect
              yield node
            rescue StandardError => ex
              node.logger.error(ex)
              Bolt::ExceptionResult.new(ex)
            ensure
              node.disconnect
            end
        end
      }
      pool.shutdown
      pool.wait_for_termination

      results_to_hash(results)
    end

    def run_command(command)
      on_each do |node|
        node.run_command(command)
      end
    end

    def run_script(script)
      on_each do |node|
        node.run_script(script)
      end
    end

    def run_task(task, input_method, arguments)
      on_each do |node|
        node.run_task(task, input_method, arguments)
      end
    end

    def file_upload(source, destination)
      on_each do |node|
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
