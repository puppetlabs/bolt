plan basic::inventory_lookup(TargetSpec $nodes) {
  # TODO: Provide inventory data to bolt_catalog to support get_targets in apply
  return apply($nodes) {
    # get_targets should return empty list for 'all'
    $t_all = get_targets('all')
    notify { "Num Targets: ${$t_all.length}": }
    # get_targets should return a new target object for any other value
    $t_foo = get_targets('foo')
    notify { "Target Name: ${$t_foo[0].name}": }
  }
}
