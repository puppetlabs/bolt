# frozen_string_literal: true

require 'net/http'
require 'openssl'

module BoltSpec
  module BoltServer
    # Waits until puppetserver is accepting requests
    def wait_until_available(timeout:, interval:)
      start = Time.now

      until healthy?
        if (Time.now - start).to_i >= timeout
          raise "Timed out waiting for puppetserver to start accepting requests"
        end

        sleep interval
      end
    end

    # Returns true if puppetserver is running
    private def healthy?
      response = puppet_server_get("/status/v1/simple", {})
      response.is_a?(Net::HTTPOK) && response.read_body == 'running'
    rescue OpenSSL::SSL::SSLError, Errno::ECONNRESET
      false
    end

    def default_config
      spec_dir = File.join(__dir__, '..', '..')
      ssl_dir = File.join(spec_dir, 'fixtures', 'ssl')
      basedir = File.join(__dir__, '..', '..', 'fixtures', 'bolt_server')
      {
        'ssl-cert' => File.join(ssl_dir, "cert.pem"),
        'ssl-key' => File.join(ssl_dir, "key.pem"),
        'ssl-ca-cert' => File.join(ssl_dir, "ca.pem"),
        'cache-dir' => File.join(spec_dir, "tmp", "cache"),
        'file-server-uri' => 'https://localhost:8140',
        'projects-dir' => File.join(basedir, 'projects')
      }
    end

    def config_data
      default_config
    end

    def target2request(target, _type = :ssh)
      req = {
        'hostname' => target.host,
        'user' => target.user
      }

      req['password'] = target.password if target.password
      req['port'] = target.port if target.port
      req['user'] = target.user if target.user

      case target.protocol
      when 'ssh'
        req['host-key-check'] = false
        if target.options.to_h.dig('private-key', 'key-data')
          req['private-key-content'] = target.options.to_h.dig('private-key', 'key-data')
        elsif target.options['private-key']
          req['private-key-content'] = File.read(target.options['private-key'])
        end
        req['port'] ||= 22
        req['user'] ||= 'root'
      when 'winrm'
        req['ssl'] = false
        req['port'] ||= 5985
      end

      req
    end

    def make_client(uri = nil)
      uri = URI(uri || config_data['file-server-uri'])
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      # rubocop:disable Naming/VariableNumber
      https.ssl_version = :TLSv1_2
      # rubocop:enable Naming/VariableNumber
      https.ca_file = config_data['ssl-ca-cert']
      https.cert = OpenSSL::X509::Certificate.new(File.read(config_data['ssl-cert']))
      https.key = OpenSSL::PKey::RSA.new(File.read(config_data['ssl-key']))
      https.verify_mode = OpenSSL::SSL::VERIFY_PEER
      https
    end

    def puppet_server_get(path, params)
      uri = URI("#{config_data['file-server-uri']}#{path}")
      uri.query = URI.encode_www_form(params)
      make_client.request(Net::HTTP::Get.new(uri))
    end

    def get_task_data(task)
      module_name, file_name = task.split('::')
      file_name ||= 'init'
      path = "/puppet/v3/tasks/#{module_name}/#{file_name}"
      params = { environment: "production" }
      resp = puppet_server_get(path, params)
      unless resp.code == '200'
        raise "request #{path} #{params} failed with: #{resp.body}"
      end
      JSON.parse(resp.body)
    end

    def build_task_request(task_name, target, params = {})
      {
        'task' => get_task_data(task_name),
        'target' => target2request(target),
        'parameters' => params
      }
    end

    def build_command_request(command, target)
      {
        'command' => command,
        'target' => target2request(target)
      }
    end

    def build_upload_request(job_id, target)
      sha = lambda do |path|
        Digest::SHA256.file(
          File.join(File.dirname(__FILE__),
                    '..', '..', 'fixtures', 'modules', 'upload_file', 'files', path)
        )
      end

      {
        'files' => [
          { "uri" => { "path" => "/puppet/v3/file_content/modules/upload_file/test-file.sh",
                       "params" => { "environment" => "production" } },
            "relative_path" => "test-file.sh",
            "sha256" => sha['test-file.sh'],
            "kind" => "file" },
          { "uri" => { "path" => "/puppet/v3/file_content/modules/upload_file/subdir",
                       "params" => { "environment" => "production" } },
            "relative_path" => "subdir",
            "sha256" => "",
            "kind" => "directory" },
          { "uri" => { "path" => "/puppet/v3/file_content/modules/upload_file/subdir/sub-file.sh",
                       "params" => { "environment" => "production" } },
            "relative_path" => "subdir/sub-file.sh",
            "sha256" => sha['subdir/sub-file.sh'],
            "kind" => "file" }
        ],
        'job_id' => job_id,
        'destination' => '/home/bolt/result-path',
        'target' => target2request(target)
      }
    end

    def build_script_request(target)
      sha = lambda do |path|
        Digest::SHA256.file(
          File.join(File.dirname(__FILE__),
                    '..', '..', 'fixtures', 'modules', 'upload_file', 'files', path)
        )
      end

      {
        'script' =>
            {
              "filename" => 'test-file.sh',
              "uri" => { "path" => "/puppet/v3/file_content/modules/upload_file/test-file.sh",
                         "params" => { "environment" => "production" } },
              "sha256" => sha['test-file.sh']
            },
        'arguments' => ['--arg'],
        'target' => target2request(target)
      }
    end

    def build_check_node_connections_request(targets)
      {
        'targets' => targets.map { |target| target2request(target) }
      }
    end
  end
end
