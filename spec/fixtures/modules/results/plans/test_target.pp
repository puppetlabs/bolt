plan results::test_target(
  String $node
) {
  $target = Target($node)
  run_task('results', $target)
}
