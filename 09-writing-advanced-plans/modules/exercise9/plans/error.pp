plan exercise9::error (TargetSpec $nodes) {
  $results = run_command('false', $nodes)
  if $results.ok {
    notice("The command succeeded")
  } else {
    notice("The command failed")
  }
}
