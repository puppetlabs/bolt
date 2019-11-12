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
