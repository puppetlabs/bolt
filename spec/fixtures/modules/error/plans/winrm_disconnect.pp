plan error::winrm_disconnect(
  TargetSpec $targets
) {
  $result = run_command('restart-service winrm', $targets, _catch_errors => true)
  wait_until_available($targets, _catch_errors => true)
  return run_command('get-service |? name -like winrm', $targets)
}

