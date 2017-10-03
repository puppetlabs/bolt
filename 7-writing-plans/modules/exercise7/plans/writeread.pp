plan exercise7::writeread(
  String $nodes,
  String $filename,
  String $message = 'Hello',
) {
  $nodes_array = split($nodes, ',')
  run_task("exercise7::write",
    $nodes_array,
    filename => $filename,
    message  => $message,
  )
  run_command("cat /tmp/${filename}", $nodes_array)
}
