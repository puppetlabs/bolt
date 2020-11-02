plan error::no_task(
  TargetSpec $targets
) {
  run_task("not::a_task", $targets)
}
