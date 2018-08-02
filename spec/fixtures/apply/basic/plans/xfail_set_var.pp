plan basic::xfail_set_var(TargetSpec $nodes) {
  return apply($nodes) {
  	$t = get_targets('foo')
    set_var($t, 'key', 'value')
  }
}