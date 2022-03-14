plan wait::no_future::subplan(
  TargetSpec $targets
) {
  background("subplan background") || {
    run_plan("wait::no_future::basic", $targets)
    return "Just a subplan, hold the mustard"
  }
  run_plan("wait::no_future::basic", $targets)
  return wait()
}
