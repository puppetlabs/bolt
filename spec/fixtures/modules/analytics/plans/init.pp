plan analytics ( $nodes ) {
  run_task('service', $nodes, name => "puppet", action => status, _catch_errors => true)
  run_task('identity', $nodes, name => "puppet", action => status, _catch_errors => true)

}
