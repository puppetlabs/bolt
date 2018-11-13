plan plans::task(TargetSpec $nodes) {
  wait_until_available($nodes)

  without_default_logging() || {
    run_task('plans::prep', $nodes)
    return run_task('plans::foo', $nodes, arg1 => true)
  }
}
