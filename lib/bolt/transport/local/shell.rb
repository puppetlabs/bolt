require 'open3'
require 'bolt/node/output'

module Bolt
  module Transport
    class Local
      class Shell
        def execute(*command, options)
          if options[:env]
            env = options[:env].each_with_object({}) { |(k, v), h| h["PT_#{k}"] = v }
            command = [env] + command
          end

          if options[:stdin]
            stdout, stderr, rc = Open3.capture3(*command, stdin_data: options[:stdin])
          else
            stdout, stderr, rc = Open3.capture3(*command)
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
