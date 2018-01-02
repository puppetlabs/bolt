plan exercise8::yesorno(String $nodes) {
  $all = $nodes.split(",")
  $results = run_task('exercise8::yesorno', $all)
  $subset = $all.filter |$node| { $results[$node][answer] == true }
  run_command("uptime", $subset)
}
