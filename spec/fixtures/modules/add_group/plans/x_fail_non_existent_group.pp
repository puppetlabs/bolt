plan add_group::x_fail_non_existent_group (TargetSpec $nodes) {
  add_to_group('foo', 'does_not_exist')
}
