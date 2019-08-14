# frozen_string_literal: true

module Bolt
  class Plugin
    class InstallAgent
      def hooks
        %w[puppet_library]
      end

      def name
        'install_agent'
      end

      def puppet_library(_opts, target, apply_prep)
        install_task = apply_prep.get_task("puppet_agent::install")
        service_task = apply_prep.get_task("service", 'action' => 'stop', 'name' => 'puppet')
        proc do
          apply_prep.run_task([target], install_task).first
          apply_prep.set_agent_feature(target)
          apply_prep.run_task([target], service_task, 'action' => 'stop', 'name' => 'puppet').first
          apply_prep.run_task([target], service_task, 'action' => 'disable', 'name' => 'puppet').first
        end
      end
    end
  end
end
