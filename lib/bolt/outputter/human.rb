# frozen_string_literal: true

require 'bolt/pal'

module Bolt
  class Outputter
    class Human < Bolt::Outputter
      COLORS = {
        red:    "31",
        green:  "32",
        yellow: "33",
        cyan:   "36"
      }.freeze

      def print_head; end

      def initialize(color, verbose, trace, stream = $stdout)
        super
        # Plans and without_default_logging() calls can both be nested, so we
        # track each of them with a "stack" consisting of an integer.
        @plan_depth = 0
        @disable_depth = 0
      end

      def colorize(color, string)
        if @color && @stream.isatty
          "\033[#{COLORS[color]}m#{string}\033[0m"
        else
          string
        end
      end

      def remove_trail(string)
        string.sub(/\s\z/, '')
      end

      def wrap(string, width = 80)
        string.gsub(/(.{1,#{width}})(\s+|\Z)/, "\\1\n")
      end

      def handle_event(event)
        case event[:type]
        when :enable_default_output
          @disable_depth -= 1
        when :disable_default_output
          @disable_depth += 1
        when :message
          print_message_event(event)
        end

        if enabled?
          case event[:type]
          when :node_start
            print_start(event[:target]) if @verbose
          when :node_result
            print_result(event[:result]) if @verbose
          when :step_start
            print_step_start(**event) if plan_logging?
          when :step_finish
            print_step_finish(**event) if plan_logging?
          when :plan_start
            print_plan_start(event)
          when :plan_finish
            print_plan_finish(event)
          end
        end
      end

      def enabled?
        @disable_depth == 0
      end

      def plan_logging?
        @plan_depth > 0
      end

      def print_start(target)
        @stream.puts(colorize(:green, "Started on #{target.safe_name}..."))
      end

      def print_result(result)
        if result.success?
          @stream.puts(colorize(:green, "Finished on #{result.target.safe_name}:"))
        else
          @stream.puts(colorize(:red, "Failed on #{result.target.safe_name}:"))
        end

        if result.error_hash
          @stream.puts(colorize(:red, remove_trail(indent(2, result.error_hash['msg']))))
        end

        if result.is_a?(Bolt::ApplyResult) && @verbose
          result.resource_logs.each do |log|
            # Omit low-level info/debug messages
            next if %w[info debug].include?(log['level'])
            message = format_log(log)
            @stream.puts(indent(2, message))
          end
        end

        # Only print results if there's something other than empty string and hash
        if result.value.empty? || (result.value.keys == ['_output'] && !result.message?)
          @stream.puts(indent(2, "#{result.action.capitalize} completed successfully with no result"))
        else
          # Only print messages that have something other than whitespace
          if result.message?
            @stream.puts(remove_trail(indent(2, result.message)))
          end

          # Use special handling if the result looks like a command or script result
          if result.generic_value.keys == %w[stdout stderr exit_code]
            safe_value = result.safe_value
            unless safe_value['stdout'].strip.empty?
              @stream.puts(indent(2, "STDOUT:"))
              @stream.puts(indent(4, safe_value['stdout']))
            end
            unless safe_value['stderr'].strip.empty?
              @stream.puts(indent(2, "STDERR:"))
              @stream.puts(indent(4, safe_value['stderr']))
            end
          elsif result.generic_value.any?
            @stream.puts(indent(2, ::JSON.pretty_generate(result.generic_value)))
          end
        end
      end

      def format_log(log)
        color = case log['level']
                when 'warn'
                  :yellow
                when 'err'
                  :red
                end
        source = "#{log['source']}: " if log['source']
        message = "#{log['level'].capitalize}: #{source}#{log['message']}"
        message = colorize(color, message) if color
        message
      end

      def print_step_start(description:, targets:, **_kwargs)
        target_str = if targets.length > 5
                       "#{targets.count} targets"
                     else
                       targets.map(&:safe_name).join(', ')
                     end
        @stream.puts(colorize(:green, "Starting: #{description} on #{target_str}"))
      end

      def print_step_finish(description:, result:, duration:, **_kwargs)
        failures = result.error_set.length
        plural = failures == 1 ? '' : 's'
        message = "Finished: #{description} with #{failures} failure#{plural} in #{duration.round(2)} sec"
        @stream.puts(colorize(:green, message))
      end

      def print_plan_start(event)
        @plan_depth += 1
        # We use this event to both mark the start of a plan _and_ to enable
        # plan logging for `apply`, so only log the message if we were called
        # with a plan
        if event[:plan]
          @stream.puts(colorize(:green, "Starting: plan #{event[:plan]}"))
        end
      end

      def print_plan_finish(event)
        @plan_depth -= 1
        plan = event[:plan]
        duration = event[:duration]
        @stream.puts(colorize(:green, "Finished: plan #{plan} in #{duration_to_string(duration)}"))
      end

      def print_summary(results, elapsed_time = nil)
        ok_set = results.ok_set
        unless ok_set.empty?
          @stream.puts format('Successful on %<size>d target%<plural>s: %<names>s',
                              size: ok_set.size,
                              plural: ok_set.size == 1 ? '' : 's',
                              names: ok_set.targets.map(&:safe_name).join(','))
        end

        error_set = results.error_set
        unless error_set.empty?
          @stream.puts colorize(:red,
                                format('Failed on %<size>d target%<plural>s: %<names>s',
                                       size: error_set.size,
                                       plural: error_set.size == 1 ? '' : 's',
                                       names: error_set.targets.map(&:safe_name).join(',')))
        end

        total_msg = format('Ran on %<size>d target%<plural>s',
                           size: results.size,
                           plural: results.size == 1 ? '' : 's')
        total_msg << " in #{duration_to_string(elapsed_time)}" unless elapsed_time.nil?
        @stream.puts total_msg
      end

      def print_table(results, padding_left = 0, padding_right = 3)
        # lazy-load expensive gem code
        require 'terminal-table'

        @stream.puts Terminal::Table.new(
          rows: results,
          style: {
            border_x: '',
            border_y: '',
            border_i: '',
            padding_left: padding_left,
            padding_right: padding_right,
            border_top: false,
            border_bottom: false
          }
        )
      end

      def print_tasks(tasks, modulepath)
        print_table(tasks)
        print_message("\nMODULEPATH:\n#{modulepath.join(File::PATH_SEPARATOR)}\n"\
                        "\nUse `bolt task show <task-name>` to view "\
                        "details and parameters for a specific task.")
      end

      # @param [Hash] task A hash representing the task
      def print_task_info(task)
        # Building lots of strings...
        pretty_params = +""
        task_info = +""
        usage = +"bolt task run --targets <node-name> #{task.name}"

        task.parameters&.each do |k, v|
          pretty_params << "- #{k}: #{v['type'] || 'Any'}\n"
          pretty_params << "    Default: #{v['default'].inspect}\n" if v.key?('default')
          pretty_params << "    #{v['description']}\n" if v['description']
          usage << if v['type'].is_a?(Puppet::Pops::Types::POptionalType)
                     " [#{k}=<value>]"
                   else
                     " #{k}=<value>"
                   end
        end

        usage << " [--noop]" if task.supports_noop

        task_info << "\n#{task.name}"
        task_info << " - #{task.description}" if task.description
        task_info << "\n\n"
        task_info << "USAGE:\n#{usage}\n\n"
        task_info << "PARAMETERS:\n#{pretty_params}\n" unless pretty_params.empty?
        task_info << "MODULE:\n"

        path = task.files.first['path'].chomp("/tasks/#{task.files.first['name']}")
        task_info << if path.start_with?(Bolt::PAL::MODULES_PATH)
                       "built-in module"
                     else
                       path
                     end
        @stream.puts(task_info)
      end

      # @param [Hash] plan A hash representing the plan
      def print_plan_info(plan)
        # Building lots of strings...
        pretty_params = +""
        plan_info = +""
        usage = +"bolt plan run #{plan['name']}"

        plan['parameters'].each do |name, p|
          pretty_params << "- #{name}: #{p['type']}\n"
          pretty_params << "    Default: #{p['default_value']}\n" unless p['default_value'].nil?
          pretty_params << "    #{p['description']}\n" if p['description']
          usage << (p.include?('default_value') ? " [#{name}=<value>]" : " #{name}=<value>")
        end

        plan_info << "\n#{plan['name']}"
        plan_info << " - #{plan['description']}" if plan['description']
        plan_info << "\n\n"
        plan_info << "USAGE:\n#{usage}\n\n"
        plan_info << "PARAMETERS:\n#{pretty_params}\n" unless plan['parameters'].empty?
        plan_info << "MODULE:\n"

        path = plan['module']
        plan_info << if path.start_with?(Bolt::PAL::MODULES_PATH)
                       "built-in module"
                     else
                       path
                     end
        @stream.puts(plan_info)
      end

      def print_plans(plans, modulepath)
        print_table(plans)
        print_message("\nMODULEPATH:\n#{modulepath.join(File::PATH_SEPARATOR)}\n"\
                        "\nUse `bolt plan show <plan-name>` to view "\
                        "details and parameters for a specific plan.")
      end

      def print_topics(topics)
        print_message("Available topics are:")
        print_message(topics.join("\n"))
        print_message("\nUse `bolt guide <topic>` to view a specific guide.")
      end

      def print_guide(guide, _topic)
        @stream.puts(guide)
      end

      def print_module_list(module_list)
        module_list.each do |path, modules|
          if (mod = modules.find { |m| m[:internal_module_group] })
            @stream.puts(colorize(:cyan, mod[:internal_module_group]))
          else
            @stream.puts(colorize(:cyan, path))
          end

          if modules.empty?
            @stream.puts('(no modules installed)')
          else
            module_info = modules.map do |m|
              version = if m[:version].nil?
                          m[:internal_module_group].nil? ? '(no metadata)' : '(built-in)'
                        else
                          m[:version]
                        end

              [m[:name], version]
            end

            print_table(module_info, 2, 1)
          end

          @stream.write("\n")
        end
      end

      def print_targets(targets)
        count = "#{targets.count} target#{'s' unless targets.count == 1}"
        @stream.puts targets.map(&:name).join("\n")
        @stream.puts colorize(:green, count)
      end

      def print_target_info(targets)
        @stream.puts ::JSON.pretty_generate(
          "targets": targets.map(&:detail)
        )
        count = "#{targets.count} target#{'s' unless targets.count == 1}"
        @stream.puts colorize(:green, count)
      end

      def print_groups(groups)
        count = "#{groups.count} group#{'s' unless groups.count == 1}"
        @stream.puts groups.join("\n")
        @stream.puts colorize(:green, count)
      end

      # @param [Bolt::ResultSet] apply_result A ResultSet object representing the result of a `bolt apply`
      def print_apply_result(apply_result, elapsed_time)
        print_summary(apply_result, elapsed_time)
      end

      # @param [Bolt::PlanResult] plan_result A PlanResult object
      def print_plan_result(plan_result)
        value = plan_result.value
        case value
        when nil
          @stream.puts("Plan completed successfully with no result")
        when Bolt::ApplyFailure, Bolt::RunFailure
          print_result_set(value.result_set)
        when Bolt::ResultSet
          print_result_set(value)
        else
          @stream.puts(::JSON.pretty_generate(plan_result, quirks_mode: true))
        end
      end

      def print_result_set(result_set)
        result_set.each { |result| print_result(result) }
        print_summary(result_set)
      end

      def print_puppetfile_result(success, puppetfile, moduledir)
        if success
          @stream.puts("Successfully synced modules from #{puppetfile} to #{moduledir}")
        else
          @stream.puts(colorize(:red, "Failed to sync modules from #{puppetfile} to #{moduledir}"))
        end
      end

      def fatal_error(err)
        @stream.puts(colorize(:red, err.message))
        if err.is_a? Bolt::RunFailure
          @stream.puts ::JSON.pretty_generate(err.result_set)
        end

        if @trace && err.backtrace
          err.backtrace.each do |line|
            @stream.puts(colorize(:red, "\t#{line}"))
          end
        end
      end

      def print_message(message)
        @stream.puts(message)
      end

      def print_error(message)
        @stream.puts(colorize(:red, message))
      end

      def print_prompt(prompt)
        @stream.print(colorize(:cyan, indent(4, prompt)))
      end

      def print_prompt_error(message)
        @stream.puts(colorize(:red, indent(4, message)))
      end

      def print_migrate_step(step)
        first, *remaining = wrap(step, 76).lines

        first     = indent(2, "→ #{first}")
        remaining = remaining.map { |line| indent(4, line) }
        step      = [first, *remaining, "\n"].join

        @stream.puts(step)
      end

      def print_migrate_error(error)
        # Running everything through 'wrap' messes with newlines. Separating
        # into lines and wrapping each individually ensures separate errors are
        # distinguishable.
        first, *remaining = error.lines
        first = colorize(:red, indent(2, "→ #{wrap(first, 76)}"))
        wrapped = remaining.map { |l| wrap(l) }
        to_print = wrapped.map { |line| colorize(:red, indent(4, line)) }
        step = [first, *to_print, "\n"].join

        @stream.puts(step)
      end

      def duration_to_string(duration)
        hrs = (duration / 3600).floor
        mins = ((duration % 3600) / 60).floor
        secs = (duration % 60)
        if hrs > 0
          "#{hrs} hr, #{mins} min, #{secs.round} sec"
        elsif mins > 0
          "#{mins} min, #{secs.round} sec"
        else
          # Include 2 decimal places if the duration is under a minute
          "#{secs.round(2)} sec"
        end
      end
    end
  end
end
