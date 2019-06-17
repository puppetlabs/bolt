plan exercise9::catch_error (TargetSpec $nodes) {
  $results = run_command('false', $nodes, _catch_errors => true)
  if $results.ok {
    out::message("The command succeeded")
  } else {
    out::message("The command failed")
  }
}
