plan plans::noop_unsupported (
  TargetSpec $targets = 'localhost'
) {
  $result = run_command('whoami', $targets)
  return $result
}
