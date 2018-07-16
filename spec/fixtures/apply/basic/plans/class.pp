plan basic::class(TargetSpec $nodes) {
  return apply($nodes) {
    include 'basic'
  }
}
