# frozen_string_literal: true

require 'open3'
require 'bolt/node/output'

module Bolt
  module Transport
    class Local
      class Shell
        def execute(*command, options)
          command = [options[:env]] + command if options[:env]

          if options[:stdin]
            stdout, stderr, rc = Open3.capture3(*command, stdin_data: options[:stdin], chdir: options[:dir])
          else
            stdout, stderr, rc = Open3.capture3(*command, chdir: options[:dir])
          end

          result_output = Bolt::Node::Output.new
          result_output.stdout << stdout unless stdout.nil?
          result_output.stderr << stderr unless stderr.nil?
          result_output.exit_code = rc.to_i
          result_output
        end
      end
    end
  end
end
