# A plan that stores facts retrieved by the minifact::retrieve plan
# from the specified nodes into the inventory.
#
# The $nodes parameter is a list of nodes to retrieve the facts for.
plan minifact(TargetSpec $nodes) {
  $result_set = run_plan(minifact::retrieve, nodes => $nodes)

  $result_set.each |$result| {
    # Store facts for nodes from which they were succefully retrieved
    if ($result.ok) {
      add_facts($result.target, $result.value)
    }
  }

  $result_set
}
