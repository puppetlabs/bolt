# frozen_string_literal: true

module Bolt
  class Outputter
    class JSON < Bolt::Outputter
      def initialize(color, trace, stream = $stdout)
        @items_open = false
        @object_open = false
        @preceding_item = false
        super(color, trace, stream)
      end

      def print_head
        @stream.puts '{ "items": ['
        @preceding_item = false
        @items_open = true
        @object_open = true
      end

      def print_event(event)
        case event[:type]
        when :node_result
          print_result(event[:result])
        end
      end

      def print_result(result)
        @stream.puts ',' if @preceding_item
        @stream.puts result.status_hash.to_json
        @preceding_item = true
      end

      def print_summary(results, elapsed_time)
        @stream.puts "],\n"
        @preceding_item = false
        @items_open = false
        @stream.puts format('"node_count": %<size>d, "elapsed_time": %<elapsed>d }',
                            size: results.size,
                            elapsed: elapsed_time)
      end

      def print_table(results)
        @stream.puts results.to_json
      end
      alias print_module_list print_table

      def print_task_info(task)
        path = task['files'][0]['path'].chomp("/tasks/#{task['files'][0]['name']}")
        task['module_dir'] = if path.start_with?(Bolt::PAL::MODULES_PATH)
                               "built-in module"
                             else
                               path
                             end
        @stream.puts task.to_json
      end

      def print_tasks(tasks, modulepath)
        print_table('tasks' => tasks, 'modulepath' => modulepath)
      end

      def print_plan_info(plan)
        path = plan.delete('module')
        plan['module_dir'] = if path.start_with?(Bolt::PAL::MODULES_PATH)
                               "built-in module"
                             else
                               path
                             end
        @stream.puts plan.to_json
      end

      def print_plans(plans, modulepath)
        print_table('plans' => plans, 'modulepath' => modulepath)
      end

      def print_apply_result(apply_result)
        @stream.puts apply_result.to_json
      end

      def print_plan_result(result)
        # Ruby JSON patches most objects to have a to_json method.
        @stream.puts result.to_json
      end

      def print_puppetfile_result(success, puppetfile, moduledir)
        @stream.puts({ "success": success,
                       "puppetfile": puppetfile,
                       "moduledir": moduledir }.to_json)
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

      def print_message(message); end
    end
  end
end
