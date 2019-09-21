plan exercise9::error (TargetSpec $nodes) {
  $results = run_command('false', $nodes)
  if $results.ok {
    out::message("The command succeeded")
  } else {
    out::message("The command failed")
  }
}
