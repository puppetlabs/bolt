plan basic::disabled(TargetSpec $nodes) {
  return apply($nodes) {
    run_task('foo', ['foo'])
  }
}
