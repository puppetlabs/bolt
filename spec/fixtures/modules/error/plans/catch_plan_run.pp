# This plan catches a RunFailure from a subplan
plan error::catch_plan_run(
  String $target
) {
 $r = run_plan('error::run_fail', 'target' => $target, '_catch_errors' => true)
 return $r.details['result_set'].first.error
}
