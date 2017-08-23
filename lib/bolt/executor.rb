require 'concurrent'

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
          ensure
            node.disconnect
          end
        end
      }
      pool.shutdown
      pool.wait_for_termination
    end

    def execute(command)
      on_each do |node|
        node.execute(command)
      end
    end

    def run_script(script)
      on_each do |node|
        node.run_script(script)
      end
    end
  end
end
