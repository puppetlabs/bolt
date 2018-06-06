# A plan that stores facts retrieved by the facts::retrieve plan
# from the specified nodes into the inventory.
#
# The $nodes parameter is a list of nodes to retrieve the facts for.
plan facts(TargetSpec $nodes) {
  $result_set = run_plan(facts::retrieve, nodes => $nodes)

  $result_set.each |$result| {
    # Store facts for nodes from which they were succefully retrieved
    if ($result.ok) {
      add_facts($result.target, $result.value)
    }
  }

  return $result_set
}
