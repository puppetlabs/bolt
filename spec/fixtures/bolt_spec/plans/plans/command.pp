plan plans::command(TargetSpec $nodes) {
  run_command('hostname', $nodes)
  return run_command('echo hello', $nodes)
}
