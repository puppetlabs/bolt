plan results::test_target(
  String $node
) {
  $target = Target($node)
  $target2 = Target($target.uri, $target.options)
  return run_task('results', $target2)
}
