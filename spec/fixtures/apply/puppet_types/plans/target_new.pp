plan puppet_types::target_new(
  TargetSpec $targets
) {
  $first = get_target($targets)
  $first.apply_prep

  return apply($first) {
    $t = Target.new('localhost')
  }
}
