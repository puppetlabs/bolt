# A plan that retrieves facts from the specified nodes by running
# an apropriate facts::* task on each. Care is taken to run a
# facts::* task corresponding to the node's platfrom on each
# node. If there is no variant of the task appropriate for some
# node's platform the node is treated as if the task had failed.
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
      'local' => if (facts::is_command_available('bash')) { 'facts::bash' } else { undef },
      default => undef,
    }
  }

  # Return a single result set composed of results from the result sets
  # returned by the individual task runs (and a result set synthesized
  # for the unsupported targets)
  ResultSet(
    $task_targets.map |$task, $targets| {
      if ($task == undef) {
        # Synthesize a result set for the unsupported targets
        ResultSet($targets.map |$target| {
          Result($target, '_error' => {
            'kind' => 'facts/unsupported',
            'msg'  => 'Target not supported by facts.',
          })
        })
      } else {
        # Run the task on the targets
        run_task($task, $targets, '_catch_errors' => true)
      }
    }.reduce([]) |$results, $result_set| {
      # Collect the results from the individual result sets
      $results + $result_set.results
    }
  )
}
