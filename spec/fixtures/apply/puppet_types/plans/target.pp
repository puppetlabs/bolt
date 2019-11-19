plan puppet_types::target (
  TargetSpec $targets
) {
  $first = get_target($targets)
  $first.apply_prep

  return apply($first) {
    notify { "ApplyTarget protocol: ${$first.protocol}": }
  }
}
