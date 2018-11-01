plan add_group::x_fail_group_name_exists (TargetSpec $nodes) {
  add_to_group(Target.new('foo'), 'foo')
}
