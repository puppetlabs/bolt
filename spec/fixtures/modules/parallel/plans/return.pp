plan parallel::return(
  TargetSpec $targets
) {
  $ts = get_targets($targets)
  return parallelize($ts) |$t| {
    return 'a'
    run_task('parallel', $t, 'time' => 2, 'val' => $t.name)
  }
}
