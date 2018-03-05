plan canary(
  Optional[String[0]] $task = undef,
  Optional[String[0]] $command = undef,
  Optional[String[0]] $script = undef,
  TargetSpec $nodes,
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

  [$canaries, $rest] = canary::random_split(get_targets($nodes), $canary_size)
  $catch_params = $params + { '_catch_errors' => true }

  if ($task) {
    $canr = run_task($task, $canaries, $catch_params)
    if ($canr.ok) {
      $restr = run_task($task, $rest, $catch_params)
    }
  } elsif ($command) {
    $canr = run_command($command, $canaries, $catch_params)
    if ($canr.ok) {
      $restr = run_command($command, $rest, $catch_params)
    }
  } elsif ($script) {
    $canr = run_script($script, $canaries, $catch_params)
    if ($canr.ok) {
      $restr = run_script($script, $rest, $catch_params)
    }
  }

  unless ($canr.ok) {
    $restr = canary::skip($rest)
  }

  canary::merge($canr, $restr)
}
