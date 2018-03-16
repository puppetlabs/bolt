# frozen_string_literal: true

require 'terminal-table'
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

      def print_event(event)
        case event[:type]
        when :node_start
          print_start(event[:target])
        when :node_result
          print_result(event[:result])
        end
      end

      def print_start(target)
        @stream.puts(colorize(:green, "Started on #{target.host}..."))
      end

      def print_result(result)
        if result.success?
          @stream.puts(colorize(:green, "Finished on #{result.target.host}:"))
        else
          @stream.puts(colorize(:red, "Failed on #{result.target.host}:"))
        end

        if result.error_hash
          @stream.puts(colorize(:red, remove_trail(indent(2, result.error_hash['msg']))))
        end

        if result.message
          @stream.puts(remove_trail(indent(2, result.message)))
        end

        # There is more information to output
        if result.generic_value
          # Use special handling if the result looks like a command or script result
          if result.generic_value.keys == %w[stdout stderr exit_code]
            unless result['stdout'].strip.empty?
              @stream.puts(indent(2, "STDOUT:"))
              @stream.puts(indent(4, result['stdout']))
            end
            unless result['stderr'].strip.empty?
              @stream.puts(indent(2, "STDERR:"))
              @stream.puts(indent(4, result['stderr']))
            end
          else
            @stream.puts(indent(2, ::JSON.pretty_generate(result.generic_value)))
          end
        end
      end

      def print_summary(results, elapsed_time)
        ok_set = results.ok_set
        unless ok_set.empty?
          @stream.puts format('Successful on %<size>d node%<plural>s: %<names>s',
                              size: ok_set.size,
                              plural: ok_set.size == 1 ? '' : 's',
                              names: ok_set.names.join(','))
        end

        error_set = results.error_set
        unless error_set.empty?
          @stream.puts colorize(:red,
                                format('Failed on %<size>d node%<plural>s: %<names>s',
                                       size: error_set.size,
                                       plural: error_set.size == 1 ? '' : 's',
                                       names: error_set.names.join(',')))
        end

        @stream.puts format('Ran on %<size>d node%<plural>s in %<elapsed>.2f seconds',
                            size: results.size,
                            plural: results.size == 1 ? '' : 's',
                            elapsed: elapsed_time)
      end

      def print_table(results)
        @stream.puts Terminal::Table.new(
          rows: results,
          style: {
            border_x: '',
            border_y: '',
            border_i: '',
            padding_left: 0,
            padding_right: 3,
            border_top: false,
            border_bottom: false
          }
        )
      end

      # @param [Hash] A hash representing the task
      def print_task_info(task)
        # Building lots of strings...
        pretty_params = +""
        task_info = +""
        usage = +"bolt task run --nodes, -n <node-name> #{task['name']}"

        if task['parameters']
          replace_data_type(task['parameters'])
          task['parameters'].each do |k, v|
            pretty_params << "- #{k}: #{v['type']}\n"
            pretty_params << "    #{v['description']}\n" if v['description']
            usage << if v['type'].is_a?(Puppet::Pops::Types::POptionalType)
                       " [#{k}=<value>]"
                     else
                       " #{k}=<value>"
                     end
          end
        end

        usage << " [--noop]" if task['supports_noop']

        task_info << "\n#{task['name']}"
        task_info << " - #{task['description']}" if task['description']
        task_info << "\n\n"
        task_info << "USAGE:\n#{usage}\n\n"
        task_info << "PARAMETERS:\n#{pretty_params}\n" if task['parameters']
        @stream.puts(task_info)
      end

      # @param [Hash] A hash representing the plan
      def print_plan_info(plan)
        # Building lots of strings...
        pretty_params = +""
        plan_info = +""
        usage = +"bolt plan run #{plan['name']}"

        plan['parameters']&.each do |p|
          name = p['name']
          pretty_params << "- #{name}: #{p['type']}\n"
          usage << if p.include?('default_value')
                     # TODO: print the default value when available
                     " [#{name}=<value>]"
                   else
                     " #{name}=<value>"
                   end
        end

        plan_info << "\n#{plan['name']}"
        plan_info << "\n\n"
        plan_info << "USAGE:\n#{usage}\n\n"
        plan_info << "PARAMETERS:\n#{pretty_params}\n" if plan['parameters']
        @stream.puts(plan_info)
      end

      # @param [Hash] A hash representing the plan result
      def print_plan_result(result)
        # If the object has a json representation display it
        if result.respond_to?(:to_json)
          # Guard against to_json methods that don't accept options
          # and don't print empty results on multiple lines
          if result.method(:to_json).arity == 0 ||
             (result.respond_to?(:empty?) && result.empty?)
            @stream.puts(result.to_json)
          else
            @stream.puts(::JSON.pretty_generate(result, quirks_mode: true))
          end
        else
          @stream.puts result.to_s
        end
      end

      def fatal_error(err)
        @stream.puts(colorize(:red, err.message))
        if err.is_a? Bolt::RunFailure
          @stream.puts ::JSON.pretty_generate(err.result_set)
        end
      end
    end

    def print_message(message)
      @stream.puts(message)
    end
  end
end
