# @summary
#   Tests that the provided Puppet Connect input data is complete, meaning that all consuming inventory targets are connectable.
#   You should run this plan with the following command:
#       PUPPET_CONNECT_INPUT_DATA=/path/to/input_data.yaml bolt plan run puppet_connect::test_input_data
#   where /path/to/input_data.yaml is the path to the input_data.yaml file containing the key-value input for the
#   puppet_connect_data plugin. If the plan fails on some targets, then you can use Bolt's --rerun option to rerun the plan on
#   just the failed targets:
#       PUPPET_CONNECT_INPUT_DATA=/path/to/input_data.yaml bolt plan run puppet_connect::test_input_data --rerun failure
#   Note that this plan should only be used as part of the copy-pastable "test input data" workflow specified in the Puppet
#   Connect docs.
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
  $unique_plugins = $targs.group_by |$t| {$t.plugin_hooks['puppet_library']}
  if ($unique_plugins.keys.length > 1) {
    out::message('Multiple puppet_library plugin hooks detected')
    $unique_plugins.each |$plug, $target_list| {
      $target_message = if ($target_list.length > 10) {
                          "${target_list.length} targets"
                        } else {
                          $target_list.join(', ')
                        }
      out::message("Plugin hook ${plug} configured for ${target_message}")
    }
    fail_plan("The puppet_library plugin config must be the same across all targets")
  }
  $targs.each |$target| {
    case $target.transport {
      'ssh': {
        $private_key_config = dig($target.config, 'ssh', 'private-key')
        if $private_key_config =~ String {
          $msg = @("END")
            The SSH private key of the ${$target} target points to a filepath on disk,
            which is not allowed in Puppet Connect. Instead, the private key contents must
            be specified and this should be done via the PuppetConnectData plugin. Below is
            an example of a Puppet Connect-compatible specification of the private-key. First,
            we start with the inventory file:
              ...
              private-key:
                _plugin: puppet_connect_data
                key: ssh_private_key
              ...

            Next is the corresponding entry in the input data file:
              ...
              ssh_private_key:
                key-data:
                  <private_key_contents>
              ...
            | END

          out::message($msg)
          fail_plan("The SSH private key of the ${$target} target points to a filepath on disk")
        }

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

    # Bolt defaults to using the "module" based form of the puppet_agent plugin. Connect defaults
    # to using the "task" based form as *only* the task based form in supported in Connect. This check
    # ensures that if the default is not being used, only task based plugins are allowed.
    $plugin = $target.plugin_hooks["puppet_library"]
    $user_configured_plugin = $plugin != { "plugin"=> "puppet_agent", "stop_service"=> true }
    if ($user_configured_plugin and $plugin["plugin"] != "task"){
      fail_plan("Only task plugins are acceptable for puppet_library hook")
    }
  }
  # The SSH/WinRM transports will report an 'unknown host' error for targets where
  # 'host' is unknown so run_command's implementation will take care of raising that
  # error for us.
  return run_command('echo Connected', $targs)
}
