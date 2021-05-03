plan container::parallel(
  TargetSpec $targets = 'localhost',
  String $image = 'ubuntu:14.04'
) {
  $_targets = get_targets($targets)
  parallelize($_targets) |$t| {
    run_container($image, 'rm' => true, 'cmd' => "sh -c 'sleep 2 && echo \"Yes\"'")
    run_command("echo \"Who's on first?\"", $t)
  }
}
