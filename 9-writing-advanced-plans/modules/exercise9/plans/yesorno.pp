plan exercise9::yesorno(String $nodes) {
  $all = $nodes.split(",")
  $results = run_task('exercise9::yesorno', $all)
  $subset = $results.filter |$result| { $result[answer] == true }.map |$result| { $result.target.name }
  run_command("uptime", $subset)
}
