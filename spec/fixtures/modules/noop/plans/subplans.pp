plan noop::subplans (
  TargetSpec $targets = 'localhost'
) {
  $result = run_plan('noop', $targets)
  return $result
}
