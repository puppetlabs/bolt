plan results::test_target(
  String $node
) {
  $target = Target.new($node)
  $target2 = Target.new({'uri' => $target.uri, 'config' => $target.config})
  return run_task('results', $target2)
}
