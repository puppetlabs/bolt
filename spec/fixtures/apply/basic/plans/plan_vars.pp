plan basic::plan_vars(TargetSpec $nodes, Optional[String] $signature = undef) {
  $targets = get_targets($nodes)
  $targets.each |$t| { $t.set_var('foo', 'hello there') }

  $plan_undef = undef
  $foo = 'hello world'
  # Make sure undef variables from parent scope are included. 
  1.each |$iter| {
    return apply($nodes) {
      notify { $foo: }
      notice("Plan vars set to undef: ${signature}${$plan_undef}")
      notice($apply_undef)
    }
  }
}
