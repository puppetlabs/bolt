plan exercise7::command(String $nodes) {
  $nodes_array = split($nodes, ',')
  run_command ("uptime",
    $nodes_array,
  )
}
