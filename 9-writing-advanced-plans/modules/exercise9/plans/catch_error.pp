plan exercise9::catch_error (TargetSpec $nodes) {
  $results = run_command('false', $nodes, _catch_errors => true)
  if $results.ok {
    notice("The command succeeded")
  } else {
    notice("The command failed")
  }
}
