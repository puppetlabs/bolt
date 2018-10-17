# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'net/http'

module BoltServer
  class FileCache
    def initialize(config, executor = Concurrent::SingleThreadExecutor.new)
      @executor = executor
      @cache_dir = config.cache_dir
      @config = config
    end

    def tmppath
      File.join(@cache_dir, 'tmp')
    end

    def setup
      FileUtils.mkdir_p(@cache_dir)
      FileUtils.mkdir_p(tmppath)
    end

    # TODO: I feel like we shouldn't drop down to this level
    # faraday is alread a dependency should we use that?
    # TODO: timeouts? proxies?
    def request_file(path, params, file)
      # TODO: handle trailing /
      uri = "#{@config.file_server_uri}#{path}"

      uri = URI(uri)
      uri.query = URI.encode_www_form(params)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      # TODO: set this from config
      https.ssl_version = :TLSv1_2
      https.ca_file = @config.ssl_ca_cert
      # TODO: Read once
      https.cert = OpenSSL::X509::Certificate.new(File.read(@config.ssl_cert))
      https.key = OpenSSL::PKey::RSA.new(File.read(@config.ssl_key))
      https.verify_mode = OpenSSL::SSL::VERIFY_PEER

      req = Net::HTTP::Get.new(uri)
      # TODO: Do we need too set any headers? should we zip?
      resp = https.request(req)
      if resp.code != "200"
        # TODO: better error
        raise "Failed to download task: #{resp.body}"
      end

      # TODO: stream file to disk
      file.write(resp.body)
      file.flush
    end

    def check_file(file_path, sha)
      File.exist?(file_path) && Digest::SHA256.file(file_path) == sha
    end

    def serial_execute(&block)
      promise = Concurrent::Promise.new(exector: @executor, &block).execute.wait
      raise promise.reason if promise.state == :rejected
      promise.value
    end

    def download_file(file_path, sha, uri)
      # if the file was downloaded while this was queued just return
      return file_path if check_file(file_path, sha)

      tmpfile = Tempfile.new(sha, tmppath)
      request_file(uri['path'], uri['params'], tmpfile)
      if Digest::SHA256.file(tmpfile.path) == sha
        # mkdir_p and mv don't error if the file exists
        FileUtils.mkdir_p(File.dirname(file_path))
        FileUtils.mv(tmpfile.path, file_path)
        file_path
      else
        # TODO: better error
        raise "Downloaded file did not match checksum"
      end
    end

    # If the file doesn't exist or is invalid redownload it
    # This downloads, validates and moves into place
    def update_file(file_data)
      sha = file_data['sha256']
      file_dir = File.join(@cache_dir, file_data['sha256'])
      file_path = File.join(file_dir, File.basename(file_data['filename']))
      if check_file(file_path, sha)
        FileUtils.touch(file_path)
        return file_path
      end

      serial_execute { download_file(file_path, sha, file_data['uri']) }
    end

    def expire
      # TODO: Implement cache cleanup
    end
  end
end
