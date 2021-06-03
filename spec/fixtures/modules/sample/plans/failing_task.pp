plan sample::failing_task (
  TargetSpec $targets = 'localhost'
) {
  return run_task('error::fail', $targets, '_catch_errors' => true)
}
