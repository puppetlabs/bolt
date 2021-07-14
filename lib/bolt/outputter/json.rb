# frozen_string_literal: true

module Bolt
  class Outputter
    class JSON < Bolt::Outputter
      def initialize(color, verbose, trace, spin, stream = $stdout)
        super
        @items_open = false
        @object_open = false
        @preceding_item = false
      end

      def print_head
        @stream.puts '{ "items": ['
        @preceding_item = false
        @items_open = true
        @object_open = true
      end

      def handle_event(event)
        case event[:type]
        when :node_result
          print_result(event[:result])
        when :message
          print_message(event[:message])
        when :verbose
          print_message(event[:message]) if @verbose
        end
      end

      def print_result(result)
        @stream.puts ',' if @preceding_item
        @stream.puts result.to_json
        @preceding_item = true
      end

      def print_summary(results, elapsed_time)
        @stream.puts "],\n"
        @preceding_item = false
        @items_open = false
        @stream.puts format('"target_count": %<size>d, "elapsed_time": %<elapsed>d }',
                            size: results.size,
                            elapsed: elapsed_time)
      end

      def print_table(results)
        @stream.puts results.to_json
      end
      alias print_module_list print_table

      # Print information about a task.
      #
      # @param task [Bolt::Task] The task information.
      #
      def print_task_info(task:)
        path = task.files.first['path'].chomp("/tasks/#{task.files.first['name']}")
        module_dir = if path.start_with?(Bolt::Config::Modulepath::MODULES_PATH)
                       "built-in module"
                     else
                       path
                     end
        @stream.puts task.to_h.merge(module_dir: module_dir).to_json
      end

      # List available tasks.
      #
      # @param tasks [Array] A list of task names and descriptions.
      # @param modulepath [Array] The modulepath.
      #
      def print_tasks(**kwargs)
        print_table(**kwargs)
      end

      def print_plugin_list(plugins:, modulepath:)
        plugins.delete(:validate_resolve_reference)
        print_table('plugins' => plugins, 'modulepath' => modulepath)
      end

      def print_plan_info(plan)
        path = plan.delete('module')
        plan['module_dir'] = if path.start_with?(Bolt::Config::Modulepath::MODULES_PATH)
                               "built-in module"
                             else
                               path
                             end
        @stream.puts plan.to_json
      end

      def print_plans(**kwargs)
        print_table(**kwargs)
      end

      def print_new_plan(**kwargs)
        print_table(**kwargs)
      end

      def print_apply_result(apply_result)
        @stream.puts apply_result.to_json
      end

      def print_plan_result(result)
        # Ruby JSON patches most objects to have a to_json method.
        @stream.puts result.to_json
      end

      def print_result_set(result_set)
        @stream.puts result_set.to_json
      end

      # Print available guide topics.
      #
      # @param topics [Array] The available topics.
      #
      def print_topics(**kwargs)
        print_table(kwargs)
      end

      # Print the guide for the specified topic.
      #
      # @param guide [String] The guide.
      # @param topic [String] The topic.
      #
      def print_guide(**kwargs)
        print_table(kwargs)
      end

      def print_plan_lookup(value)
        @stream.puts(value.to_json)
      end

      def print_puppetfile_result(success, puppetfile, moduledir)
        @stream.puts({ success: success,
                       puppetfile: puppetfile,
                       moduledir: moduledir.to_s }.to_json)
      end

      # Print target names and where they came from.
      #
      # @param adhoc [Hash] Adhoc targets provided on the command line.
      # @param inventory [Hash] Targets provided from the inventory.
      # @param targets [Array] All targets.
      # @param count [Integer] Number of targets.
      #
      def print_targets(adhoc:, inventory:, targets:, count:, **_kwargs)
        adhoc[:targets]     = adhoc[:targets].map { |t| t['name'] }
        inventory[:targets] = inventory[:targets].map { |t| t['name'] }
        targets             = targets.map { |t| t['name'] }
        @stream.puts({ adhoc: adhoc, inventory: inventory, targets: targets, count: count }.to_json)
      end

      # Print target names and where they came from.
      #
      # @param adhoc [Hash] Adhoc targets provided on the command line.
      # @param inventory [Hash] Targets provided from the inventory.
      # @param targets [Array] All targets.
      # @param count [Integer] Number of targets.
      #
      def print_target_info(adhoc:, inventory:, targets:, count:, **_kwargs)
        @stream.puts({ adhoc: adhoc, inventory: inventory, targets: targets, count: count }.to_json)
      end

      # Print inventory group information.
      #
      # @param count [Integer] Number of groups in the inventory.
      # @param groups [Array] Names of groups in the inventory.
      #
      def print_groups(count:, groups:, **_kwargs)
        @stream.puts({ count: count, groups: groups }.to_json)
      end

      def fatal_error(err)
        @stream.puts "],\n" if @items_open
        @stream.puts '"_error": ' if @object_open
        err_obj = err.to_h
        if @trace && err.backtrace
          err_obj[:details] ||= {}
          err_obj[:details][:backtrace] = err.backtrace
        end
        @stream.puts err_obj.to_json
        @stream.puts '}' if @object_open
      end

      def print_message(message)
        $stderr.puts(message)
      end
      alias print_error print_message

      def print_action_step(step)
        $stderr.puts(step)
      end
      alias print_action_error print_action_step
    end
  end
end
