# @summary
#   Test plan to verify the wait() function behavior when not passed Futures
plan wait::no_future::basic(
  TargetSpec $targets
) {
  # Create futures
  $msgs = ["Run immediately", "Who's on first", "What's on second", "I don't know's on third"]
  $msgs.each |$msg| {
    background($msg) || {
      if $msg =~ /Run immediately/ {
          return $msg
      } else {
        # Include a sleep to ensure that this does some "work" before returning
        run_command("sleep 0.1", $targets)
        return $msg
      }
    }
  }
  # Give the first Future a chance to run
  run_command('hostname', $targets)
  # Wait for messages
  return wait()
}
