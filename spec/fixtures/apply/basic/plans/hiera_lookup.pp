plan basic::hiera_lookup(TargetSpec $nodes) {
  return apply($nodes) {
    notify { "hello ${lookup('hiera_data')}": }
  }
}