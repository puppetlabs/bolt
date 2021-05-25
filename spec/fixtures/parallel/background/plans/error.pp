plan background::error(
  TargetSpec $targets,
  Boolean $sleep = false
) {
  background() || {
    run_command("exit 1", $targets)
    out::message("Finished backgrounded block")
  }

  if $sleep {
      run_command("sleep 1", $targets)
  }
  return 'Still ran successfully'
}
