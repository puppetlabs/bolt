plan exercise7::writeread (
  TargetSpec $nodes,
  String     $filename,
  String     $message = 'Hello',
) {
  run_task(
    'exercise7::write',
    $nodes,
    filename => $filename,
    message  => $message,
  )
  return run_command("cat /tmp/${filename}", $nodes)
}
