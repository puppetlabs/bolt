plan basic::trusted(TargetSpec $nodes) {
  return apply($nodes) {
    notify { "trusted ${trusted}": }
  }
}
