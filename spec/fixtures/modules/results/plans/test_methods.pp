plan results::test_methods(
  String $target,
  Optional[String] $fail = 'false'
) {
  if($fail) {
    $result = run_task('results', [$target], 'fail' => 'true')
  } else {
    $result = run_task('results', [$target])
  }

  # Test to_s works
  $str = "result ${result}"
  # return ok
  $result.ok
}
