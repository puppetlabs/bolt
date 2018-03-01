plan vars(String $host) {
  $target = get_targets($host)[0]
  $target.set_var('bugs', 'bunny')
  run_command("echo 'Vars for ${host}: ${$target.vars}'", $host)
}
