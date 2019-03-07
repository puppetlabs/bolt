# frozen_string_literal: true

require 'shellwords'

def validate_sudo_options(options, logger)
  if options['sudo-password'] && options['run-as'].nil?
    logger.warn("--sudo-password will not be used without specifying a " \
                "user to escalate to with --run-as")
  end

  run_as_cmd = options['run-as-command']
  if run_as_cmd && (!run_as_cmd.is_a?(Array) || run_as_cmd.any? { |n| !n.is_a?(String) })
    raise Bolt::ValidationError, "run-as-command must be an Array of Strings, received #{run_as_cmd}"
  end
end

def sudo_prompt
  '[sudo] Bolt needs to run as another user, password: '
end

def execute_prep(command,
                 options,
                 sudoable: false,
                 run_as_command: nil,
                 run_as: nil,
                 conn_user: nil)

  if options[:interpreter]
    command.is_a?(Array) ? command.unshift(options[:interpreter]) : [options[:interpreter], command]
  end

  command_str = command.is_a?(String) ? command : Shellwords.shelljoin(command)

  escalate = sudoable && run_as && conn_user != run_as
  use_sudo = escalate && run_as_command.nil?
  if escalate
    if use_sudo
      sudo_flags = ["sudo", "-S", "-u", run_as, "-p", sudo_prompt]
      sudo_flags += ["-E"] if options[:environment]
      sudo_str = Shellwords.shelljoin(sudo_flags)
      command_str = "#{sudo_str} #{command_str}"
    else
      run_as_str = Shellwords.shelljoin(run_as_command + [run_as])
      command_str = "#{run_as_str} #{command_str}"
    end
  end

  command_str
end
