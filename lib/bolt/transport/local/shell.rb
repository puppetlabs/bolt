# frozen_string_literal: true

require 'open3'
require 'bolt/node/output'

module Bolt
  module Transport
    class Local < Base
      class Shell
        include Streaming

        def initialize(target)
          @target = target
          @logger = Logging.logger[@target.host]
        end

        def execute(*command, options)
          command = [options[:env]] + command if options[:env]

          opts = { chdir: options[:dir] }
          stdin_data = options[:stdin] if options[:stdin]

          log_output "Executing: #{command}"
          stdout, stderr, rc = Open3.popen3(*command, opts) do |i, o, e, t|
            readers = { out: o, err: e }.map do |key, stream|
              Thread.new do
                output = StringIO.new
                until (raw_line = stream.gets).nil?
                  output << raw_line
                  log_output "#{key}: #{raw_line}"
                end
                output.string
              end
            end
            begin
              i.write stdin_data
            rescue Errno::EPIPE => e
              @logger.debug "Pipe closed while running #{command} on #{@target.name}: #{e}"
            end
            i.close
            (readers + [t]).map(&:value)
          end

          if rc.to_i == 0
            log_output "Command returned successfully"
          else
            log_output("Command failed with exit code #{rc}", :info)
          end

          result_output = Bolt::Node::Output.new
          result_output.stdout << stdout unless stdout.nil?
          result_output.stderr << stderr unless stderr.nil?
          result_output.exit_code = rc.to_i
          result_output
        rescue StandardError
          log_output "Command aborted"
          raise
        end
      end
    end
  end
end
