plan noop::unsupported (
  TargetSpec $targets = 'localhost'
) {
  run_command('whoami', $targets)
}
