plan prep::version(TargetSpec $nodes) {
  $nodes.apply_prep

  return run_task("puppet_agent::version", $nodes)
}
