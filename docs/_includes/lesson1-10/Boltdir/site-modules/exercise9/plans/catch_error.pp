plan exercise9::catch_error (TargetSpec $targets) {
  $results = run_command('false', $targets, _catch_errors => true)
  if $results.ok {
    out::message("The command succeeded")
  } else {
    out::message("The command failed")
  }
}
