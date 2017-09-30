plan sample::three_tasks(String $first_targets, String $second_targets, String $third_targets) {

  $first_array = split($first_targets, ',')
  $second_array = split($second_targets, ',')
  $third_array = split($third_targets, ',')

  run_task(sample::echo, $first_array,
    message => "first task",
  )

  run_task(sample::echo, $second_array,
    message => "second task",
  )

  run_task(sample::echo, $third_array,
    message => "third task",
  )

}
