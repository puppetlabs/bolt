plan device_test::facts(
  $nodes = 'localhost',
) {

  apply_prep($nodes)
  $f = get_targets($nodes).map |$t| { [$t.name, $t.facts] }
  return($f)
}
