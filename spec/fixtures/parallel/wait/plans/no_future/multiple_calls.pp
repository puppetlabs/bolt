plan wait::no_future::multiple_calls (
  TargetSpec $targets
) {
  $first = run_plan('wait::no_future::subplan', $targets)
  $second = run_plan('wait::no_future::subplan', $target)
}
