# frozen_string_literal: true

require 'bolt/pal'

module Bolt
  class Outputter
    class Human < Bolt::Outputter
      COLORS = {
        dim:    "2", # Dim, the other color of the rainbow
        red:    "31",
        green:  "32",
        yellow: "33",
        cyan:   "36"
      }.freeze

      def print_head; end

      def initialize(color, verbose, trace, spin, stream = $stdout)
        super
        # Plans and without_default_logging() calls can both be nested, so we
        # track each of them with a "stack" consisting of an integer.
        @plan_depth = 0
        @disable_depth = 0
        @pinwheel = %w[- \\ | /]
      end

      def colorize(color, string)
        if @color && @stream.isatty
          "\033[#{COLORS[color]}m#{string}\033[0m"
        else
          string
        end
      end

      def start_spin
        return unless @spin && @stream.isatty && !@spinning
        @spinning = true
        @spin_thread = Thread.new do
          loop do
            sleep(0.1)
            @stream.print(colorize(:cyan, @pinwheel.rotate!.first + "\b"))
          end
        end
      end

      def stop_spin
        return unless @spin && @stream.isatty && @spinning
        @spinning = false
        @spin_thread.terminate
        @stream.print("\b")
      end

      def remove_trail(string)
        string.sub(/\s\z/, '')
      end

      # Wraps a string to the specified width. Lines only wrap
      # at whitespace.
      #
      def wrap(string, width = 80)
        return string unless string.is_a?(String)
        string.gsub(/(.{1,#{width}})(\s+|\Z)/, "\\1\n")
      end

      # Trims a string to a specified width, adding an ellipsis if it's longer.
      #
      def truncate(string, width = 80)
        return string unless string.is_a?(String) && string.length > width
        string.lines.first[0...width].gsub(/\s\w+\s*$/, '...')
      end

      def handle_event(event)
        case event[:type]
        when :enable_default_output
          @disable_depth -= 1
        when :disable_default_output
          @disable_depth += 1
        when :message
          print_message(event[:message])
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
          when :container_start
            print_container_start(event) if plan_logging?
          when :container_finish
            print_container_finish(event) if plan_logging?
          when :start_spin
            start_spin
          when :stop_spin
            stop_spin
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

      def print_container_result(result)
        if result.success?
          @stream.puts(colorize(:green, "Finished running container #{result.object}:"))
        else
          @stream.puts(colorize(:red, "Failed running container #{result.object}:"))
        end

        if result.error_hash
          @stream.puts(colorize(:red, remove_trail(indent(2, result.error_hash['msg']))))
          return 0
        end

        # Only print results if there's something other than empty string and hash
        safe_value = result.safe_value
        if safe_value['stdout'].strip.empty? && safe_value['stderr'].strip.empty?
          @stream.puts(indent(2, "Running container #{result.object} completed successfully with no result"))
        else
          unless safe_value['stdout'].strip && safe_value['stdout'].strip.empty?
            @stream.puts(indent(2, "STDOUT:"))
            @stream.puts(indent(4, safe_value['stdout']))
          end
          unless safe_value['stderr'].strip.empty?
            @stream.puts(indent(2, "STDERR:"))
            @stream.puts(indent(4, safe_value['stderr']))
          end
        end
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

          case result.action
          when 'command', 'script'
            safe_value = result.safe_value
            @stream.puts(indent(2, safe_value['merged_output'])) unless safe_value['merged_output'].strip.empty?
          when 'lookup'
            @stream.puts(indent(2, result['value']))
          else
            if result.generic_value.any?
              @stream.puts(indent(2, ::JSON.pretty_generate(result.generic_value)))
            end
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

      def print_container_start(image:, **_kwargs)
        @stream.puts(colorize(:green, "Starting: run container '#{image}'"))
      end

      def print_container_finish(event)
        result = if event[:result].is_a?(Bolt::ContainerFailure)
                   event[:result].result
                 else
                   event[:result]
                 end

        if result.success?
          @stream.puts(colorize(:green, "Finished: run container '#{result.object}' succeeded."))
        else
          @stream.puts(colorize(:red, "Finished: run container '#{result.object}' failed."))
        end
        print_container_result(result) if @verbose
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

      def format_table(results, padding_left = 0, padding_right = 3)
        # lazy-load expensive gem code
        require 'terminal-table'

        Terminal::Table.new(
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
        command = Bolt::Util.powershell? ? 'Get-BoltTask -Name <TASK NAME>' : 'bolt task show <TASK NAME>'

        tasks = tasks.map do |name, description|
          description = truncate(description, 72)
          [name, description]
        end

        @stream.puts colorize(:cyan, 'Tasks')
        @stream.puts tasks.any? ? format_table(tasks, 2) : indent(2, 'No available tasks')
        @stream.puts

        @stream.puts colorize(:cyan, 'Modulepath')
        @stream.puts indent(2, modulepath.join(File::PATH_SEPARATOR))
        @stream.puts

        @stream.puts colorize(:cyan, 'Additional information')
        @stream.puts indent(2, "Use '#{command}' to view details and parameters for a specific task.")
      end

      # @param [Hash] task A hash representing the task
      def print_task_info(task)
        params = (task.parameters || []).sort

        info = +''

        # Add task name and description
        info << colorize(:cyan, "#{task.name}\n")
        info << if task.description
                  indent(2, task.description.chomp)
                else
                  indent(2, 'No description')
                end
        info << "\n\n"

        # Build usage string
        usage = +''
        usage << if Bolt::Util.powershell?
                   "Invoke-BoltTask -Name #{task.name} -Targets <targets>"
                 else
                   "bolt task run #{task.name} --targets <targets>"
                 end
        usage << (Bolt::Util.powershell? ? ' [-Noop]' : ' [--noop]') if task.supports_noop
        params.each do |name, data|
          usage << if data['type']&.start_with?('Optional')
                     " [#{name}=<value>]"
                   else
                     " #{name}=<value>"
                   end
        end

        # Add usage
        info << colorize(:cyan, "Usage\n")
        info << indent(2, wrap(usage))
        info << "\n"

        # Add parameters, if any
        if params.any?
          info << colorize(:cyan, "Parameters\n")
          params.each do |name, data|
            info << indent(2, "#{colorize(:yellow, name)}  #{colorize(:dim, data['type'] || 'Any')}\n")
            info << indent(4, "#{wrap(data['description']).chomp}\n") if data['description']
            info << indent(4, "Default: #{data['default'].inspect}\n") if data.key?('default')
            info << "\n"
          end
        end

        # Add module location
        path = task.files.first['path'].chomp("/tasks/#{task.files.first['name']}")
        info << colorize(:cyan, "Module\n")
        info << if path.start_with?(Bolt::Config::Modulepath::MODULES_PATH)
                  indent(2, 'built-in module')
                else
                  indent(2, path)
                end

        @stream.puts info
      end

      # @param [Hash] plan A hash representing the plan
      def print_plan_info(plan)
        params = plan['parameters'].sort

        info = +''

        # Add plan name and description
        info << colorize(:cyan, "#{plan['name']}\n")
        info << if plan['description']
                  indent(2, plan['description'].chomp)
                else
                  indent(2, 'No description')
                end
        info << "\n\n"

        # Build the usage string
        usage = +''
        usage << if Bolt::Util.powershell?
                   "Invoke-BoltPlan -Name #{plan['name']}"
                 else
                   "bolt plan run #{plan['name']}"
                 end
        params.each do |name, data|
          usage << (data.include?('default_value') ? " [#{name}=<value>]" : " #{name}=<value>")
        end

        # Add usage
        info << colorize(:cyan, "Usage\n")
        info << indent(2, wrap(usage))
        info << "\n"

        # Add parameters, if any
        if params.any?
          info << colorize(:cyan, "Parameters\n")

          params.each do |name, data|
            info << indent(2, "#{colorize(:yellow, name)}  #{colorize(:dim, data['type'])}\n")
            info << indent(4, "#{wrap(data['description']).chomp}\n") if data['description']
            info << indent(4, "Default: #{data['default_value']}\n") unless data['default_value'].nil?
            info << "\n"
          end
        end

        # Add module location
        info << colorize(:cyan, "Module\n")
        info << if plan['module'].start_with?(Bolt::Config::Modulepath::MODULES_PATH)
                  indent(2, 'built-in module')
                else
                  indent(2, plan['module'])
                end

        @stream.puts info
      end

      def print_plans(plans, modulepath)
        command = Bolt::Util.powershell? ? 'Get-BoltPlan -Name <PLAN NAME>' : 'bolt plan show <PLAN NAME>'

        plans = plans.map do |name, description|
          description = truncate(description, 72)
          [name, description]
        end

        @stream.puts colorize(:cyan, 'Plans')
        @stream.puts plans.any? ? format_table(plans, 2) : indent(2, 'No available plans')
        @stream.puts

        @stream.puts colorize(:cyan, 'Modulepath')
        @stream.puts indent(2, modulepath.join(File::PATH_SEPARATOR))
        @stream.puts

        @stream.puts colorize(:cyan, 'Additional information')
        @stream.puts indent(2, "Use '#{command}' to view details and parameters for a specific plan.")
      end

      def print_topics(topics)
        print_message("Available topics are:")
        print_message(topics.join("\n"))
        print_message("\nUse 'bolt guide <TOPIC>' to view a specific guide.")
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

            @stream.puts format_table(module_info, 2, 1)
          end

          @stream.write("\n")
        end
      end

      def print_targets(target_list, inventory_source, default_inventory, target_flag)
        adhoc = colorize(:yellow, "(Not found in inventory file)")

        targets  = []
        targets += target_list[:inventory].map { |target| [target.name, nil] }
        targets += target_list[:adhoc].map { |target| [target.name, adhoc] }

        info = +''

        # Add target list
        info << colorize(:cyan, "Targets\n")
        info << if targets.any?
                  format_table(targets, 2, 2).to_s
                else
                  indent(2, 'No targets')
                end
        info << "\n\n"

        info << format_inventory_source(inventory_source, default_inventory)
        info << format_target_summary(target_list[:inventory].count, target_list[:adhoc].count, target_flag, false)

        @stream.puts info
      end

      def print_target_info(target_list, inventory_source, default_inventory, target_flag)
        adhoc_targets     = target_list[:adhoc].map(&:name).to_set
        inventory_targets = target_list[:inventory].map(&:name).to_set
        targets           = target_list.values.flatten.sort_by(&:name)

        info = +''

        if targets.any?
          adhoc = colorize(:yellow, " (Not found in inventory file)")

          targets.each do |target|
            info << colorize(:cyan, target.name)
            info << adhoc if adhoc_targets.include?(target.name)
            info << "\n"
            info << indent(2, target.detail.to_yaml.lines.drop(1).join)
            info << "\n"
          end
        else
          info << colorize(:cyan, "Targets\n")
          info << indent(2, "No targets\n\n")
        end

        info << format_inventory_source(inventory_source, default_inventory)
        info << format_target_summary(inventory_targets.count, adhoc_targets.count, target_flag, true)

        @stream.puts info
      end

      private def format_inventory_source(inventory_source, default_inventory)
        info = +''

        # Add inventory file source
        info << colorize(:cyan, "Inventory source\n")
        info << if inventory_source
                  indent(2, "#{inventory_source}\n")
                else
                  indent(2, wrap("Tried to load inventory from #{default_inventory}, but the file does not exist\n"))
                end
        info << "\n"
      end

      private def format_target_summary(inventory_count, adhoc_count, target_flag, detail_flag)
        info = +''

        # Add target count summary
        count = "#{inventory_count + adhoc_count} total, "\
                "#{inventory_count} from inventory, "\
                "#{adhoc_count} adhoc"
        info << colorize(:cyan, "Target count\n")
        info << indent(2, count)

        # Add filtering information
        unless target_flag && detail_flag
          info << colorize(:cyan, "\n\nAdditional information\n")

          unless target_flag
            opt = Bolt::Util.windows? ? "'-Targets', '-Query', or '-Rerun'" : "'--targets', '--query', or '--rerun'"
            info << indent(2, "Use the #{opt} option to view specific targets\n")
          end

          unless detail_flag
            opt = Bolt::Util.windows? ? '-Detail' : '--detail'
            info << indent(2, "Use the '#{opt}' option to view target configuration and data")
          end
        end

        info
      end

      def print_groups(groups, inventory_source, default_inventory)
        info = +''

        # Add group list
        info << colorize(:cyan, "Groups\n")
        info << indent(2, groups.join("\n"))
        info << "\n\n"

        # Add inventory file source
        info << format_inventory_source(inventory_source, default_inventory)

        # Add group count summary
        info << colorize(:cyan, "Group count\n")
        info << indent(2, "#{groups.count} total")

        @stream.puts info
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
        when Bolt::ContainerResult
          print_container_result(value)
        when Bolt::ContainerFailure
          print_container_result(value.result)
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

      def print_action_step(step)
        first, *remaining = wrap(step, 76).lines

        first     = indent(2, "→ #{first}")
        remaining = remaining.map { |line| indent(4, line) }
        step      = [first, *remaining, "\n"].join

        @stream.puts(step)
      end

      def print_action_error(error)
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
