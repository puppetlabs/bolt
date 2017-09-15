require 'concurrent'
require 'bolt/result'

module Bolt
  class Executor
    def self.from_uris(uris)
      new(uris.map { |uri| Bolt::Node.from_uri(uri, nil, nil, nil) })
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
              Bolt::ExceptionFailure.new(ex)
            ensure
              node.disconnect
            end
        end
      }
      pool.shutdown
      pool.wait_for_termination

      results
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

    def run_task(task, input_method, arguments)
      on_each do |node|
        node.run_task(task, input_method, arguments)
      end
    end

    def file_upload(source, destination)
      on_each do |node|
        result = node.upload(source, destination)
        if result.is_a?(Bolt::Success)
          Bolt::Success.new(
            "Uploaded '#{source}' to '#{node.host}:#{destination}'"
          )
        else
          result
        end
      end
    end
  end
end
