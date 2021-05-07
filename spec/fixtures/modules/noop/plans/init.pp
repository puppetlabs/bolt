plan noop (
  TargetSpec $targets = 'localhost'
) {
  $result = run_task('noop', $targets)
  return $result
}
