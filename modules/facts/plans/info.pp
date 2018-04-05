# A plan that prints basic OS information for the specified nodes. It first
# runs the facts::retrieve plan to retrieve facts from the nodes, then
# compiles the desired OS information from the os fact value of each nodes.
#
# The $nodes parameter is a list of the nodes for which to print the OS
# information.
plan facts::info(TargetSpec $nodes) {
  return run_plan(facts::retrieve, nodes => $nodes).reduce([]) |$info, $r| {
    if ($r.ok) {
      $info + "${r.target.name}: ${r[os][name]} ${r[os][release][full]} (${r[os][family]})"
    } else {
      $info # don't include any info for nodes which failed
    }
  }
}
