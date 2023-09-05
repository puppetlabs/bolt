# frozen_string_literal: true

require 'fileutils'
require 'io/console'

module PupEnt
  class Access
    RBAC_PREFIX = ":4433/rbac-api"

    def initialize(token_location)
      @token_location = token_location
      @logger = Bolt::Logger.logger(self)
    end

    def login(client, lifetime)
      $stderr.print("Enter your Puppet Enterprise credentials.\n")
      $stderr.print("Username: ")
      username = $stdin.gets.to_s.chomp
      $stderr.print("Password: ")
      # noecho ensures we don't print anything to the console
      # while the user is typing the password
      password = $stdin.noecho(&:gets).to_s.chomp!
      $stderr.puts

      body = {
        login: username,
        password: password,
        lifetime: lifetime
      }
      response, = client.pe_post("/v1/auth/token", body, sensitive: true)
      FileUtils.mkdir_p(File.dirname(token_location))
      File.open(token_location, File::CREAT | File::WRONLY) do |fd|
        fd.write(response['token'])
      end
    end

    def show
      File.open(token_location, File::RDONLY).read
    rescue Errno::ENOENT
      msg = "No token file!"
      @logger.error(msg)
      raise Bolt::Error.new(msg, 'bolt/no-token')
    end

    def delete_token
      @logger.info("Deleting token...")
      File.delete(token_location)
      @logger.info("Done.")
    rescue Errno::ENOENT
      msg = "No token file!"
      @logger.error(msg)
      raise Bolt::Error.new(msg, 'bolt/no-token')
    end

    def token_location
      @token_location ||= File.join(ENV['HOME'], '.pupent', 'token')
    end
  end
end
