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

      def print_task_info(task)
        path = task.files.first['path'].chomp("/tasks/#{task.files.first['name']}")
        module_dir = if path.start_with?(Bolt::Config::Modulepath::MODULES_PATH)
                       "built-in module"
                     else
                       path
                     end
        @stream.puts task.to_h.merge(module_dir: module_dir).to_json
      end

      def print_tasks(**kwargs)
        print_table(**kwargs)
      end

      def print_plugin_list(plugins, modulepath)
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

      def print_topics(topics)
        print_table('topics' => topics)
      end

      def print_guide(guide, topic)
        @stream.puts({
          'topic' => topic,
          'guide' => guide
        }.to_json)
      end

      def print_plan_lookup(value)
        @stream.puts(value.to_json)
      end

      def print_puppetfile_result(success, puppetfile, moduledir)
        @stream.puts({ success: success,
                       puppetfile: puppetfile,
                       moduledir: moduledir.to_s }.to_json)
      end

      def print_targets(target_data, _target_flag)
        target_data[:adhoc][:targets]     = target_data[:adhoc][:targets].map { |t| t['name'] }
        target_data[:inventory][:targets] = target_data[:inventory][:targets].map { |t| t['name'] }
        target_data[:targets]             = target_data[:targets].map { |t| t['name'] }
        @stream.puts target_data.to_json
      end

      def print_target_info(target_data, _target_flag)
        @stream.puts target_data.to_json
      end

      def print_groups(group_data)
        @stream.puts group_data.slice(:count, :groups).to_json
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
