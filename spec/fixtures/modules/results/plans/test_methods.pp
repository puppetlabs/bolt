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
  # Test filter_set works
  $filtered = $result.filter_set |$r| {
    $r['tag'] == "you're it"
  }.targets
  notice("Filtered set: ${$filtered}")
  # return ok
  return $result.ok
}
