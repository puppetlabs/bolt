plan sample::failing_task (
  TargetSpec $targets = 'localhost'
) {
  return run_task('sample::error', $targets, '_catch_errors' => true)
}
