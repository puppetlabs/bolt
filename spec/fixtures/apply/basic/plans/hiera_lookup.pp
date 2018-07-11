plan basic::hiera_lookup(TargetSpec $nodes) {
  return apply($nodes) {
    notify { "hello ${hiera('hiera_data')}": }
  }
}