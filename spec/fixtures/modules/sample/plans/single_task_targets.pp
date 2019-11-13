# one line plan to show we can run a task by name
plan sample::single_task_targets(
  TargetSpec       $targets,
  Optional[String] $description = undef,
) {
  return if $description {
    run_task("sample::echo", $targets, $description, message => "hi there", _catch_errors => true)
  } else {
    run_task("sample::echo", $targets, message => "hi there", _catch_errors => true)
  }
}
