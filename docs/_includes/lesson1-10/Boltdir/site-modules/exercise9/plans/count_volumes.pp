plan exercise9::count_volumes (TargetSpec $targets) {
  $result = run_command('df', $targets)
  return $result.map |$r| {
    $line_count = $r['stdout'].split("\n").length - 1
    "${$r.target.name} has ${$line_count} volumes"
  }
}
