plan results::test_methods(
  String $target,
  Boolean $fail = false
) {
  if($fail) {
    $result = run_task('results', [$target], 'fail' => 'true', '_catch_errors' => true)
  } else {
    $result = run_task('results', [$target])
  }

  # Test to_s works
  $str = "result ${result}"
  # return ok
  return $result.ok
}
