plan plans::plan_calling_plan(TargetSpec $targets) {
  return run_plan('plans::command', targets => $targets)
}
