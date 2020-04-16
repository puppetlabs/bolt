plan plans::plan_with_targets(TargetSpec $targets) {
  return run_command('hostname', $targets)
}
