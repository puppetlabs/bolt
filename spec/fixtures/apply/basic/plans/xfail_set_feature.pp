plan basic::xfail_set_feature(TargetSpec $nodes) {
  return apply($nodes) {
  	$t = get_targets('foo')
    set_features($t, 'puppet-agent')
  }
}