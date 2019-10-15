plan sample::noop (
  TargetSpec $nodes
) {
  return run_task('sample::noop', $nodes, message => 'This works', _noop => true)
}
