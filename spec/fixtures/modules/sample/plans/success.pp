plan sample::successful_task (
  TargetSpec $targets = 'localhost'
) {
  return run_task('sample::success', $targets)
}
