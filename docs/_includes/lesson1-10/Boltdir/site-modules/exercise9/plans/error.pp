plan exercise9::error (TargetSpec $targets) {
  $results = run_command('false', $targets)
  if $results.ok {
    out::message("The command succeeded")
  } else {
    out::message("The command failed")
  }
}
