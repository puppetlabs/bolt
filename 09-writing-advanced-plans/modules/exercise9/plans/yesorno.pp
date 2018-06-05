plan exercise9::yesorno (TargetSpec $nodes) {
  $results = run_task('exercise9::yesorno', $nodes)
  $subset = $results.filter |$result| { $result[answer] == true }.map |$result| { $result.target }
  return run_command("uptime", $subset)
}
