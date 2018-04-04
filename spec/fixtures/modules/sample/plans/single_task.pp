# one line plan to show we can run a task by name
plan sample::single_task(
  TargetSpec       $nodes,
  Optional[String] $description = undef,
) {
  if $description {
    run_task("sample::echo", $nodes, $description, message => "hi there", _catch_errors => true)
  } else {
    run_task("sample::echo", $nodes, message => "hi there", _catch_errors => true)
  }
}
