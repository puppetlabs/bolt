# A plan that simply prints basic OS information for the specified nodes.
# It first runs the minifact::retrieve plan to retrieve facts from the nodes,
# then compiles the desired OS information from the os fact value of each
# node.
#
# The $nodes parameter is a list of the nodes for which to print the OS
# information.
plan minifact::info(TargetSpec $nodes) {
  run_plan(minifact::retrieve, nodes => $nodes).reduce([]) |$info, $r| {
    if ($r.ok) {
      $info + "${r.target.name}: ${r[os][name]} ${r[os][release][full]} (${r[os][family]})"
    } else {
      $info # don't include any info for nodes which failed
    }
  }
}
