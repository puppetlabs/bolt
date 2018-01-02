plan sample::upper_case(String $nodes) {
  $node_array = split($nodes, ',')
  run_task("Sample::Echo", $node_array, message => "Up, up, and away")
}