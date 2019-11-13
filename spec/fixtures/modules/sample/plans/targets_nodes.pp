# one line plan to show we can run a task by name
plan sample::targets_nodes(
  TargetSpec $targets,
  TargetSpec $nodes
) {
  return 'done'
}
