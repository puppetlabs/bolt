plan sample::two_tasks(String $first_targets, String $second_targets) {

  $first_array = split($first_targets, ',')
  $second_array = split($second_targets, ',')

  run_task(sample::echo, $first_array,
    message => "first task",
  )

  run_task(sample::echo, $second_array,
    message => "second task",
  )

}
