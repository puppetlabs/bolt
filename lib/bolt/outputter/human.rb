module Bolt
  class Outputter
    class Human < Bolt::Outputter
      def print_head; end

      def print_result(node, result)
        color = result.success? ? "\033[32m" : "\033[31m"
        @stream.print color if @stream.isatty
        @stream.puts "#{node.host}:"
        @stream.print "\033[0m" if @stream.isatty
        @stream.puts
        @stream.puts result.message
        @stream.puts
      end

      def print_summary(results, elapsed_time)
        @stream.puts format("Ran on %d node%s in %.2f seconds",
                            results.size,
                            results.size > 1 ? 's' : '',
                            elapsed_time)
      end

      def print_plan(result)
        @stream.puts result
      end

      def fatal_error(e); end
    end
  end
end
