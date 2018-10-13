plan basic::notify(TargetSpec $nodes) {

  return apply($nodes) {
    notify { "Apply: Hi!": }
  }
}
