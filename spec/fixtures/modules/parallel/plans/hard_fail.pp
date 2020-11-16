plan parallel::hard_fail(
  TargetSpec $targets
) {
  $ts = get_targets($targets)
  return parallelize($ts) |$t| {
    foo
    run_task('parallel', $t, 'time' => 2, 'val' => $t.name)
  }
}
