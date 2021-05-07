plan plans::noop (
  TargetSpec $targets = 'localhost'
) {
  $result = run_task('plans::noop', $targets)
  return $result
}
