plan test::incept(
  String $target
) {
  return run_plan(test::id, target => $target)
}
