plan exercise9::yesorno(String $nodes) {
  $all = $nodes.split(",")
  $results = run_task('exercise9::yesorno', $all)
  $subset = $all.filter |$node| { $results[$node][answer] == true }
  run_command("uptime", $subset)
}
