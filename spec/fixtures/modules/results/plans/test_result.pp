plan results::test_result(TargetSpec $nodes){
  $result_set = run_command('echo hi', $nodes)
  notice("Result status: ${$result_set.first.status}")
  return $result_set
}
