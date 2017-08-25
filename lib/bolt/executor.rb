require 'concurrent'
require 'bolt/result'

module Bolt
  class Executor
    def initialize(nodes)
      @nodes = nodes
    end

    def on_each
      pool = Concurrent::FixedThreadPool.new(5)
      @nodes.map { |node|
        pool.post do
          begin
            node.connect
            yield node
          rescue StandardError => ex
            node.logger.error(ex)
            Bolt::ExceptionFailure.new(ex)
          ensure
            node.disconnect
          end
        end
      }
      pool.shutdown
      pool.wait_for_termination
    end

    def execute(command)
      results = Concurrent::Map.new

      on_each do |node|
        results[node] = node.execute(command)
      end

      results
    end

    def run_script(script)
      results = Concurrent::Map.new

      on_each do |node|
        results[node] = node.run_script(script)
      end

      results
    end
  end
end
