require 'net/ssh'
require 'net/sftp'

module Bolt
  class SSH < Node
    def connect
      options = { logger: @transport_logger }
      options[:port] = @port if @port
      options[:password] = @password if @password

      @session = Net::SSH.start(@host, @user, options)
    end

    def disconnect
      @session.close if @session && !@session.closed?
    end

    def execute(command)
      result_output = Bolt::ResultOutput.new
      status = {}
      @session.exec!(command, status: status) do |_, stream, data|
        result_output.stdout << data if stream == :stdout
        result_output.stderr << data if stream == :stderr
      end
      if status[:exit_code].zero?
        Bolt::Success.new(result_output.stdout.string, result_output)
      else
        Bolt::Failure.new(status[:exit_code], result_output)
      end
    end

    def copy(source, destination)
      Net::SFTP::Session.new(@session).connect! do |sftp|
        sftp.upload!(source, destination)
      end
      Bolt::Success.new
    rescue => e
      Bolt::ExceptionFailure.new(e)
    end

    def make_tempdir
      Bolt::Success.new(@session.exec!('mktemp -d').chomp)
    rescue => e
      Bolt::ExceptionFailure.new(e)
    end

    def run_script(script)
      remote_path = ''
      dir = ''
      result = nil

      make_tempdir.then do |value|
        dir = value
        remote_path = "#{dir}/#{File.basename(script)}"
        Bolt::Success.new
      end.then do
        copy(script, remote_path)
      end.then do
        execute("chmod u+x '#{remote_path}'")
      end.then do
        result = execute("'#{remote_path}'")
      end.then do
        execute("rm -f '#{remote_path}'")
      end.then do
        execute("rmdir '#{dir}'")
        result
      end
    end
  end
end
