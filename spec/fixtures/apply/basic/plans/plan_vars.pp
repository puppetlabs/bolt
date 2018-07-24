plan basic::plan_vars(TargetSpec $nodes) {
  $targets = get_targets($nodes)
  $targets.each |$t| { $t.set_var('foo', 'hello there') }

  $foo = 'hello world'
  return apply($nodes) {
    notify { $foo: }
  }
}
