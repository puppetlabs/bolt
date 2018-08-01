plan prep(TargetSpec $nodes) {
  $nodes.apply_prep

  return apply($nodes) {
    notify { "Hello ${$trusted['certname']}": }
  }
}
