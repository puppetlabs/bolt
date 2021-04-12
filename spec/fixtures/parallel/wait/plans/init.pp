# @summary
#   Test plan to verify the wait() function behavior
#
# @param start
#   Index to start slicing the array of Futures
# @param end
#   Index to finish slicing the array of Futures
plan wait(
  Integer $start = 0,
  Integer $end = -1
) {
  # Create 3 futures
  $futures = ["Who's on first", "What's on second", "I don't know's on third"].map |$msg| {
    background() || {
      # Include a sleep to ensure that this does some "work" before returning
      ctrl::sleep(0.1)
      return $msg
    }
  }
  # Print slice of futures (defaulting to all) in reverse order to ensure that
  # the order passed in takes precedence over the order created + executed.
  out::message(wait(reverse($futures[$start, $end])))
  # Ensure this isn't printed until `wait` returns
  out::message("That's what I want to find out.")
}
