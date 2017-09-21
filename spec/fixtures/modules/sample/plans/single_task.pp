# one line plan to show we can run a task by name
plan sample::single_task($nodes = String) {
  run_task (
    "sample::echo", $nodes,
    message => "hi there"
  )
}
