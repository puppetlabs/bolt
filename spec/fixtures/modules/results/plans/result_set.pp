plan results::result_set (
  String $target
) {
  run_task('results', [$target], 'fail' => 'true', '_catch_errors' => true)
}
