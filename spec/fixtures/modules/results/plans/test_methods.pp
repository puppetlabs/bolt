plan results::test_methods(
  String $target,
  Boolean $fail = false
) {
  if($fail) {
    $result = run_task('results', [$target], 'fail' => 'true', '_abort' => false)
  } else {
    $result = run_task('results', [$target])
  }

  # Test to_s works
  $str = "result ${result}"
  # return ok
  $result.ok
}
