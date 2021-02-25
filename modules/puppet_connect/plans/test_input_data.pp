# @summary
#   Tests that the provided Puppet Connect input data is complete, meaning that all consuming inventory targets are connectable.
#
# This plan should only be used as part of the copy-pastable "test input data"
# workflow specified in the Puppet Connect docs.
#
# @param targets
#   The set of targets to test. Usually this should be 'all', the default.
#
# @return ResultSet the result of invoking the 'is connectable?' query on all
# the targets. Note that this query currently consists of running the 'echo'
# command.
#
plan puppet_connect::test_input_data(TargetSpec $targets = 'all') {
  $targs = get_targets($targets)
  $targs.each |$target| {
    case $target.transport {
      'ssh': {
        # Disable SSH autoloading to prevent false positive results
        # (input data is wrong but target is still connectable due
        # to autoloaded config)
        set_config($target, ['ssh', 'load-config'], false)
        # Maintain configuration parity with Puppet Connect to improve
        # the reliability of our test
        set_config($target, ['ssh', 'host-key-check'], false)
      }
      'winrm': {
        # Maintain configuration parity with Puppet Connect
        set_config($target, ['winrm', 'ssl'], false)
        set_config($target, ['winrm', 'ssl-verify'], false)
      }
      default: {
        fail_plan("Inventory contains target ${target} with unsupported transport, must be ssh or winrm")
      }
    }
  }
  # The SSH/WinRM transports will report an 'unknown host' error for targets where
  # 'host' is unknown so run_command's implementation will take care of raising that
  # error for us.
  return run_command('echo Connected', $targs)
}
