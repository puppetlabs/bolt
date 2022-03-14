plan parallel::catch_error_outer(
  TargetSpec $targets
) {
  $ts = get_targets($targets)
  catch_errors() || {
    parallelize($ts) |$t| {
      run_task('error::fail', $t)
    }
  }
  return "We made it"
}
