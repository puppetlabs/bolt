# A plan that retrieves facts from the specified nodes by running
# an appropriate facts::* task on each. Care is taken to run a
# facts::* task corresponding to the node's platfrom on each
# node.
#
# The $nodes parameter is a list of the nodes to retrieve the facts
# from.
plan facts::retrieve(TargetSpec $nodes) {
  $targets = get_targets($nodes)

  # Build a mapping from the names of the tasks to run to the lists of
  # targets to run the tasks on
  $task_targets = $targets.facts::group_by |$target| {
    $target.protocol ? {
      'ssh'   => 'facts::bash',
      'winrm' => 'facts::powershell',
      'pcp'   => 'facts::ruby',
      'local' => 'facts::bash',
    }
  }

  # Return a single result set composed of results from the result sets
  # returned by the individual task runs.
  return ResultSet(
    $task_targets.map |$task, $targets| {
      run_task($task, $targets, '_catch_errors' => true)
    }.reduce([]) |$results, $result_set| {
      # Collect the results from the individual result sets
      $results + $result_set.results
    }
  )
}
