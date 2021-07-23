function parallel::custom_function (
  TargetSpec $target
) {
  run_command('whoami', $target)
}
