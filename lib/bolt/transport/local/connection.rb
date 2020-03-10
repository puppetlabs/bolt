# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'bolt/node/output'
require 'bolt/util'

module Bolt
  module Transport
    class Local < Simple
      class Connection
        attr_accessor :user, :logger, :target

        CHUNK_SIZE = 4096

        def initialize(target)
          @target = target
          # The familiar problem: Etc.getlogin is broken on osx
          @user = ENV['USER'] || Etc.getlogin
          @logger = Logging.logger[self]
        end

        def shell
          @shell ||= Bolt::Shell::Bash.new(target, self)
        end

        def copy_file(source, dest)
          @logger.debug { "Uploading #{source}, to #{dest}" }
          if source.is_a?(StringIO)
            Tempfile.create(File.basename(dest)) do |f|
              f.write(source.read)
              FileUtils.mv(t, dest)
            end
          else
            # Mimic the behavior of `cp --remove-destination`
            # since the flag isn't supported on MacOS
            FileUtils.cp_r(source, dest, remove_destination: true)
          end
        rescue StandardError => e
          message = "Could not copy file to #{dest}: #{e}"
          raise Bolt::Node::FileError.new(message, 'COPY_ERROR')
        end

        def execute(command, **options)
          command_arr = options[:environment].nil? ? Array(command) : [options[:environment], *command]

          # Prepare the variables!
          result_output = Bolt::Node::Output.new
          in_buffer = options[:stdin] || ''
          # Chunks of this size will be read in one iteration
          index = 0
          timeout = 0.1

          inp, out, err, t = Open3.popen3(*command_arr)
          read_streams = { out => String.new,
                           err => String.new }
          write_stream = in_buffer.empty? ? [] : [inp]

          # True while the process is running or waiting for IO input
          while t.alive?
            # See if we can read from out or err, or write to in
            ready_read, ready_write, = select(read_streams.keys, write_stream, nil, timeout)

            # Read from out and err
            ready_read&.each do |stream|
              read_streams[stream] << stream.readpartial(CHUNK_SIZE)
            rescue EOFError
            end

            # select will either return an empty array if there are no
            # writable streams or nil if no IO object is available before the
            # timeout is reached.
            writable = if ready_write.respond_to?(:empty?)
                         !ready_write.empty?
                       else
                         !ready_write.nil?
                       end

            begin
              if writable && index < in_buffer.length
                to_print = in_buffer[index..-1]
                written = inp.write_nonblock to_print
                index += written

                if index >= in_buffer.length && !write_stream.empty?
                  inp.close
                  write_stream = []
                end
              end
              # If a task has stdin as an input_method but doesn't actually
              # read from stdin, the task may return and close the input stream
            rescue Errno::EPIPE
              write_stream = []
            end
          end
          # Read any remaining data in the pipe. Do not wait for
          # EOF in case the pipe is inherited by a child process.
          read_streams.each do |stream, _|
            loop { read_streams[stream] << stream.read_nonblock(CHUNK_SIZE) }
          rescue Errno::EAGAIN, EOFError
          end
          result_output.stdout << read_streams[out]
          result_output.stderr << read_streams[err]
          result_output.exit_code = t.value.exitstatus
          result_output
        end
      end
    end
  end
end
