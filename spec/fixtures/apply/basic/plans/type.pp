plan basic::type(TargetSpec $nodes) {
  return apply($nodes) {
    warn { "Hello!": }
  }
}
