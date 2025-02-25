# frozen_string_literal: true

require 'bolt/container_result'
require 'bolt/error'
require 'bolt/util'

# Run a container and return its output to stdout and stderr.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:run_container) do
  # Run a container.
  # @param image The name of the image to run.
  # @param options A hash of additional options.
  # @option options [Boolean] _catch_errors Whether to catch raised errors.
  # @option options [String] cmd A command to run in the container.
  # @option options [Hash[String, Data]] env_vars Map of environment variables to set.
  # @option options [Hash[Integer, Integer]] ports A map of container ports to
  #   publish. Keys are the host port, values are the corresponding container
  #   port.
  # @option options [Boolean] rm Whether to remove the container once it exits.
  # @option options [Hash[String, String]] volumes A map of absolute paths on
  #   the host to absolute paths on the remote to mount.
  # @option options [String] workdir The working directory within the container.
  # @return Output from the container.
  # @example Run Nginx proxy manager
  #   run_container('jc21/nginx-proxy-manager', 'ports' => { 80 => 80, 81 => 81, 443 => 443 })
  dispatch :run_container do
    param 'String[1]', :image
    optional_param 'Hash[String[1], Any]', :options
    return_type 'ContainerResult'
  end

  def run_container(image, options = {})
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'run_container')
    end

    # Send Analytics Report
    executor = Puppet.lookup(:bolt_executor)
    executor.report_function_call(self.class.name)

    options = options.transform_keys { |k| k.sub(/^_/, '').to_sym }
    validate_options(options)

    if options.key?(:env_vars)
      options[:env_vars] = options[:env_vars].transform_values do |val|
        [Array, Hash].include?(val.class) ? val.to_json : val
      end
    end

    if options[:ports]
      ports = options[:ports].each_with_object([]) do |(host_port, container_port), acc|
        acc << "-p"
        acc << "#{host_port}:#{container_port}"
      end
    end

    if options[:volumes]
      volumes = options[:volumes].each_with_object([]) do |(host_path, remote_path), acc|
        begin
          FileUtils.mkdir_p(host_path)
        rescue StandardError => e
          message = "Unable to create host volume directory #{host_path}: #{e.message}"
          raise Bolt::Error.new(message, 'bolt/file-error')
        end
        acc << "-v"
        acc << "#{host_path}:#{remote_path}"
      end
    end

    # Run the container
    # `docker run` will automatically pull the image if it isn't already downloaded
    cmd = %w[run]
    cmd += Bolt::Util.format_env_vars_for_cli(options[:env_vars]) if options[:env_vars]
    cmd += volumes if volumes
    cmd += ports if ports
    cmd << "--rm" if options[:rm]
    cmd += %W[-w #{options[:workdir]}] if options[:workdir]
    cmd << image
    cmd += Shellwords.shellsplit(options[:cmd]) if options[:cmd]

    executor.publish_event(type: :container_start, image: image)
    out, err, status = Bolt::Util.exec_docker(cmd)

    o = out.is_a?(String) ? out.dup.force_encoding('utf-8') : out
    e = err.is_a?(String) ? err.dup.force_encoding('utf-8') : err

    unless status.exitstatus.zero?
      result = Bolt::ContainerResult.from_exception(e,
                                                    status.exitstatus,
                                                    image,
                                                    position: Puppet::Pops::PuppetStack.top_of_stack)
      executor.publish_event(type: :container_finish, result: result)
      if options[:catch_errors]
        return result
      else
        raise Bolt::ContainerFailure, result
      end
    end

    value = { 'stdout' => o, 'stderr' => e, 'exit_code' => status.exitstatus }
    result = Bolt::ContainerResult.new(value, object: image)
    executor.publish_event(type: :container_finish, result: result)
    result
  end

  def validate_options(options)
    if options.key?(:env_vars)
      ev = options[:env_vars]
      unless ev.is_a?(Hash)
        msg = "Option 'env_vars' must be a hash. Received #{ev} which is a #{ev.class}"
        raise Bolt::ValidationError, msg
      end

      if (bad_keys = ev.keys.reject { |k| k.is_a?(String) }).any?
        msg = "Keys for option 'env_vars' must be strings: #{bad_keys.map(&:inspect).join(', ')}"
        raise Bolt::ValidationError, msg
      end
    end

    if options.key?(:volumes)
      volumes = options[:volumes]
      unless volumes.is_a?(Hash)
        msg = "Option 'volumes' must be a hash. Received #{volumes} which is a #{volumes.class}"
        raise Bolt::ValidationError, msg
      end

      if (bad_vs = volumes.reject { |k, v| k.is_a?(String) && v.is_a?(String) }).any?
        msg = "Option 'volumes' only accepts strings for keys and values. " \
              "Received: #{bad_vs.map(&:inspect).join(', ')}"
        raise Bolt::ValidationError, msg
      end
    end

    if options.key?(:cmd) && !options[:cmd].is_a?(String)
      cmd = options[:cmd]
      msg = "Option 'cmd' must be a string. Received #{cmd} which is a #{cmd.class}"
      raise Bolt::ValidationError, msg
    end

    if options.key?(:workdir) && !options[:workdir].is_a?(String)
      wd = options[:workdir]
      msg = "Option 'workdir' must be a string. Received #{wd} which is a #{wd.class}"
      raise Bolt::ValidationError, msg
    end

    if options.key?(:ports)
      ports = options[:ports]
      unless ports.is_a?(Hash)
        msg = "Option 'ports' must be a hash. Received #{ports} which is a #{ports.class}"
        raise Bolt::ValidationError, msg
      end

      if (bad_ps = ports.reject { |k, v| k.is_a?(Integer) && v.is_a?(Integer) }).any?
        msg = "Option 'ports' only accepts integers for keys and values. " \
              "Received: #{bad_ps.map(&:inspect).join(', ')}"
        raise Bolt::ValidationError, msg
      end
    end
  end
end
