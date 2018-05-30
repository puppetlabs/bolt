# A plan that retrieves facts from the specified nodes by running
# the 'facts' task on each.
#
# The $nodes parameter is a list of the nodes to retrieve the facts
# from.
plan facts::retrieve(TargetSpec $nodes) {
  return run_task('facts', $nodes, '_catch_errors' => true)
}
