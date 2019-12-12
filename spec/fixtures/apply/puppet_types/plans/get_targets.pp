plan puppet_types::get_targets(
  TargetSpec $targets
) {
  $first = get_target($targets)
  $first.apply_prep

  return apply($first) {
    $names = get_targets($targets).map |$t| {
      $t.name
    }
    notify { $names.join(","): }
  }
}
