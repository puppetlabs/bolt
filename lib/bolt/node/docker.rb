require 'docker'

module Bolt
  class Docker < Node
    def connect
      @container = ::Docker::Container.get(@host)
    end

    def disconnect; end

    def execute(command)
      result_output = Bolt::ResultOutput.new
      out, err, code = @container.exec([command])
      result_output.stdout << out
      result_output.stderr << err
      if code.zero?
        Bolt::Success.new(out, result_output)
      else
        Bolt::Failure.new(code, result_output)
      end
    end

    def copy(source, destination)
      contents = File.open(source, 'rb', &:read)
      @container.store_file(destination, contents)
      Bolt::Success.new
    rescue => e
      Bolt::ExceptionFailure.new(e)
    end

    def make_tempdir
      Bolt::Success.new(@container.exec(['mktemp -d']))
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
