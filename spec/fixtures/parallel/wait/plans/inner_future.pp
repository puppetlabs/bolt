# @summary
#   Test plan to verify the wait() waits for futures created inside futures
plan wait::inner_future() {
  # Create 'outer' future
  $outer_future = background() || {
    out::message("Before inner future")
    # Ensure this future does some work
    ctrl::sleep(0.1)
    # Create inner future
    background() || {
      return "In inner future"
    }
  }
  wait($outer_future)
}
