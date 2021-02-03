# @summary
#   Run a task, command, or script on targets and aggregate the results as
#   a count of targets for each value of a key.
#
# This plan accepts an action and a list of targets. The action can be the name
# of a task, a script, or a command to run. It will run the action on the
# targets and aggregate the key/value pairs in each Result into a hash, mapping
# the keys to a hash of each distinct value and how many targets returned that
# value for the key.
#
# @param command
#   The command to run. Mutually exclusive with script and task.
# @param script
#   The path to the script to run. Mutually exclusive with command and task.
# @param task
#   The name of the task to run. Mutually exclusive with command and script.
# @param targets
#   The list of targets to run the action on.
# @param params
#   A hash of parameters and options to pass to the `run_*` function
#   associated with the action (e.g. run_task).
plan aggregate::count(
  Optional[String[0]] $task = undef,
  Optional[String[0]] $command = undef,
  Optional[String[0]] $script = undef,
  TargetSpec $targets,
  Hash[String, Data] $params = {}
) {

  # Validation
  $type_count = [$task, $command, $script].reduce(0) |$acc, $v| {
    if ($v) {
      $acc + 1
    } else {
      $acc
    }
  }

  if ($type_count == 0) {
    fail_plan("Must specify a command, script, or task to run", 'aggregate/invalid-params')
  }

  if ($type_count > 1) {
    fail_plan("Must specify only one command, script, or task to run", 'aggregate/invalid-params')
  }

  $res = if ($task) {
    run_task($task, $targets, $params)
  } elsif ($command) {
    run_command($command, $targets, $params)
  } elsif ($script) {
    run_script($script, $targets, $params)
  }

  return aggregate::count($res)
}
