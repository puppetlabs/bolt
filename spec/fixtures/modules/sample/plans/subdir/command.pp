plan sample::subdir::command (
  TargetSpec $targets
) {
  return run_command('echo From subdir', $targets)
}
