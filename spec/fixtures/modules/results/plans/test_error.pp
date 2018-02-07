plan results::test_error (
  String $target
) {
    $result = run_task('results', [$target], 'fail' => 'true', '_catch_errors' => true)
    $result.first.error.message
}
