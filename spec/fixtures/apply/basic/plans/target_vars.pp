plan basic::target_vars(TargetSpec $nodes) {
  $targets = get_targets($nodes)
  $targets.each |$t| { $t.set_var('foo', 'hello there') }

  return apply($nodes) {
    notify { $foo: }
  }
}
