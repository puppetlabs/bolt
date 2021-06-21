# @summary
#   Run a task, command or script on canary targets before running it on all targets.
#
# This plan accepts a action and a $targets parameter. The action can be the name
# of a task, a script or a command to run. It will run the action on a canary
# group of targets and only continue to the rest of the targets if it succeeds on
# all canaries. This returns a ResultSet object with a Result for every target.
# Any skipped targets will have a 'canary/skipped-target' error kind.
#
# @param task
#  The name of the task to run. Mutually exclusive with command and script.
# @param command
#   The command to run. Mutually exclusive with task and script.
# @param script
#   The script to run. Mutually exclusive with task and command.
# @param targets
#   The target to run on.
# @param params
#   The parameters to use for the task.
# @param canary_size
#   How many targets to use in the canary group.
#
# @return ResultSet a merged resultset from running the action on all targets
#
# @example Run a command
#   run_plan(canary, command => 'whoami', targets => $mytargets)
#
plan canary(
  Optional[String[0]] $task = undef,
  Optional[String[0]] $command = undef,
  Optional[String[0]] $script = undef,
  TargetSpec $targets,
  Hash[String, Data] $params = {},
  Integer $canary_size = 1
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
    fail_plan("Must specify a command, script, or task to run", 'canary/invalid-params')
  }

  if ($type_count > 1) {
    fail_plan("Must specify only one command, script, or task to run", 'canary/invalid-params')
  }

  [$canaries, $rest] = canary::random_split(get_targets($targets), $canary_size)
  $catch_params = $params + { '_catch_errors' => true }

  if ($task) {
    $action = 'run_task'
    $object = $task
    $canr = run_task($task, $canaries, $catch_params)
    if ($canr.ok) {
      $restr = run_task($task, $rest, $catch_params)
    }
  } elsif ($command) {
    $action = 'run_command'
    $object = $command
    $canr = run_command($command, $canaries, $catch_params)
    if ($canr.ok) {
      $restr = run_command($command, $rest, $catch_params)
    }
  } elsif ($script) {
    $action = 'run_script'
    $object = $script
    $canr = run_script($script, $canaries, $catch_params)
    if ($canr.ok) {
      $restr = run_script($script, $rest, $catch_params)
    }
  }

  unless ($canr.ok) {
    $restr = canary::skip($rest)
  }

  $merged_result = canary::merge($canr, $restr)

  unless ($merged_result.ok) {
    if ($canr.ok) {
      $message = "Plan failed for ${merged_result.error_set.count} targets."
    }
    else {
      $message = "${canr.error_set.count} canary target failures. ${restr.count} targets skipped."
    }
    $details = {'action' => $action,
                'object' => $object,
                'result_set' => $merged_result}
    fail_plan($message, 'bolt/run-failure', $details)
  }

  return $merged_result
}
