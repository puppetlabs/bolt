plan puppet_types::get_target(
  TargetSpec $targets
) {
  $first = get_target($targets)
  $first.apply_prep

  return apply($first) {
    $name = get_target($targets).name
    notify { $name: }
  }
}
