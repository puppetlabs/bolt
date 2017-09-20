# one line plan to show we can run a task by name
plan sample::two_tasks($nodes = Hash) {

  run_task(mymodule::mytask, $nodes['webservers'],
    param1 => $task1_value,
    param2 => $task2_value,
  )

}
