require 'concurrent'

module Bolt
  class Executor
    def initialize(nodes)
      @nodes = nodes
    end

    def execute(command)
      pool = Concurrent::FixedThreadPool.new(5)
      @nodes.map { |node|
        pool.post do
          node.connect
          begin
            node.execute(command)
          ensure
            node.disconnect
          end
        end
      }
      pool.shutdown
      pool.wait_for_termination
    end
  end
end
