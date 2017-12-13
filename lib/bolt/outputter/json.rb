module Bolt
  class Outputter
    class JSON < Bolt::Outputter
      def initialize(stream = $stdout)
        @items_open = false
        @object_open = false
        @preceding_item = false
        super(stream)
      end

      def print_head
        @stream.puts '{ "items": ['
        @preceding_item = false
        @items_open = true
        @object_open = true
      end

      def print_event(node, event)
        case event[:type]
        when :node_result
          print_result(node, event[:result])
        end
      end

      def print_result(node, result)
        item = {
          name: node.uri,
          status: result.success? ? 'success' : 'failure',
          result: result.to_result
        }

        @stream.puts ',' if @preceding_item
        @stream.puts item.to_json
        @preceding_item = true
      end

      def print_summary(results, elapsed_time)
        @stream.puts "],\n"
        @preceding_item = false
        @items_open = false
        @stream.puts format('"node_count": %d, "elapsed_time": %d }',
                            results.size,
                            elapsed_time)
      end

      def print_plan(result)
        # Ruby JSON patches most objects to have a to_json method.
        @stream.puts result.to_json
      end

      def fatal_error(e)
        @stream.puts "],\n" if @items_open
        @stream.puts '"_error": ' if @object_open
        @stream.puts e.to_json
        @stream.puts '}' if @object_open
      end
    end
  end
end
