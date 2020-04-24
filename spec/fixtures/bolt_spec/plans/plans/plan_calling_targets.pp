plan plans::plan_calling_targets(TargetSpec $targets) {
  return run_plan('plans::plan_with_targets', $targets)
}
