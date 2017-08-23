require 'net/ssh'
require 'net/sftp'

module Bolt
  class SSH < Node
    def initialize(host, port = nil, user = nil, password = nil)
      @host = host
      @user = user
      @port = port
      @password = password
    end

    def connect
      options = {}
      options[:port] = @port if @port
      options[:password] = @password if @password

      @session = Net::SSH.start(@host, @user, **options)
    end

    def disconnect
      @session.close if @session && !@session.closed?
    end

    def execute(command)
      @session.exec!(command) do |_, stream, data|
        $stdout << data if stream == :stdout
        $stderr << data if stream == :stderr
      end
    end

    def copy(source, destination)
      Net::SFTP::Session.new(@session).connect! do |sftp|
        sftp.upload!(source, destination)
      end
    end

    def make_tempdir
      @session.exec!('mktemp -d').chomp
    end

    def run_script(script)
      dir = make_tempdir
      remote_path = "#{dir}/#{File.basename(script)}"
      copy(script, remote_path)
      execute("chmod u+x \"#{remote_path}\"")
      execute("\"#{remote_path}\"")
      execute("rm -f \"#{remote_path}\"")
      execute("rmdir \"#{dir}\"")
    end
  end
end
