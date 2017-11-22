module Bolt
  class Outputter
    class Human < Bolt::Outputter
      COLORS = { red: "31",
                 green: "32",
                 yellow: "33" }.freeze

      def print_head; end

      def colorize(color, string)
        if @stream.isatty
          "\033[#{COLORS[color]}m#{string}\033[0m"
        else
          string
        end
      end

      def indent(indent, string)
        indent = ' ' * indent
        string.gsub(/^/, indent.to_s)
      end

      def remove_trail(string)
        string.sub(/\s\z/, '')
      end

      def print_event(node, event)
        case event[:type]
        when :node_start
          print_start(node)
        when :node_result
          print_result(node, event[:result])
        end
      end

      def print_start(node)
        @stream.puts(colorize(:green, "Started on #{node.host}..."))
      end

      def print_result(node, result)
        if result.success?
          @stream.puts(colorize(:green, "Finished on #{node.host}:"))
        else
          @stream.puts(colorize(:red, "Failed on #{node.host}:"))
        end

        if result.error
          if result.error['msg']
            @stream.puts(colorize(:red, remove_trail(indent(2, result.error['msg']))))
          else
            @stream.puts(colorize(:red, remove_trail(indent(2, result.error))))
          end
        end

        if result.message
          @stream.puts(remove_trail(indent(2, result.message)))
        end

        if result.instance_of? Bolt::TaskResult
          @stream.puts(indent(2, ::JSON.pretty_generate(result.value)))
        elsif result.instance_of? Bolt::CommandResult
          @stream.puts(indent(2, "STDOUT:"))
          @stream.puts(indent(4, result.stdout))
          @stream.puts(indent(2, "STDERR:"))
          @stream.puts(indent(4, result.stderr))
        end
      end

      def print_summary(results, elapsed_time)
        @stream.puts format("Ran on %d node%s in %.2f seconds",
                            results.size,
                            results.size == 1 ? '' : 's',
                            elapsed_time)
      end

      def print_plan(result)
        @stream.puts result
      end

      def fatal_error(e); end
    end
  end
end
