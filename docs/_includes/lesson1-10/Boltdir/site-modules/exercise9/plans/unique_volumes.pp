plan exercise9::unique_volumes (TargetSpec $targets) {
  $result = run_command('df', $targets)
  $volumes = $result.reduce([]) |$arr, $r| {
    $lines = $r['stdout'].split("\n")[1,-1]
    $volumes = $lines.map |$line| {
      $line.split(' ')[-1]
    }
    $arr + $volumes
  }

  return $volumes.unique
}
