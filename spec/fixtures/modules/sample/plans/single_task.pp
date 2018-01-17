# one line plan to show we can run a task by name
plan sample::single_task(String $nodes) {
  $node_array = split($nodes, ',')
  run_task (
    "sample::echo", $node_array,
    message => "hi there",
    '_abort' => false,
  )
}
