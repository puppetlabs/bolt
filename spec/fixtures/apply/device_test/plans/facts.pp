plan device_test::facts(
  $nodes = 'localhost',
) {
  # rely on the agent already being installed
  apply_prep($nodes)
  $f = get_targets($nodes).map |$t| { [$t.name, $t.facts] }
  return($f)
}
