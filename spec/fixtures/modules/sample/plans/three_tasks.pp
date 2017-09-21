plan sample::three_tasks($nodes) {

  run_task(sample::echo, $nodes,
    message => "first task",
  )

  run_task(sample::echo, $nodes,
    message => "second task",
  )

  run_task(sample::echo, $nodes,
    message => "third task",
  )

}
