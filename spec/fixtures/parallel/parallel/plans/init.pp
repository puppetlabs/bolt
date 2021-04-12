plan parallel(
  TargetSpec $targets
) {
  $ts = get_targets($targets)
  return parallelize($ts) |$t| {
    run_task('parallel', $t, 'time' => 2, 'val' => 'print')
  }
}
