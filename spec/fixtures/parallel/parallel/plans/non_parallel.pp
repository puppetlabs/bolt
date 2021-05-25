plan parallel::non_parallel(
  TargetSpec $targets
) {
  $ts = get_targets($targets)
  parallelize($ts) |$t| {
    $a = 2*2
    $b = 3+5
  }

  return "Success"
}
