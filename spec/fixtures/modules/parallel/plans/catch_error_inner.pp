plan parallel::catch_error_inner(
  TargetSpec $targets
) {
  $ts = get_targets($targets)
  parallelize($ts) |$t| {
    catch_errors() || {
      run_task('error::fail', $t)
    }
  }
  return "We made it"
}
