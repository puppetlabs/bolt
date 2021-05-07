plan noop::metaparameter (
  TargetSpec $targets = 'localhost'
) {
  $result = run_task('noop', $targets, '_noop' => false)
  return $result
}
