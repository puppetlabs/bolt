plan basic::run_as_apply(
  TargetSpec $nodes,
  String $user
) {
  return run_plan(basic::whoami, $nodes, _run_as => $user)
}
