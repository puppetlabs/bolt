plan test::run_as_user(String $target, String $user) {
  run_command('whoami', $target, _run_as => $user)
  upload_file('test/id.sh', "/home/${user}/id.sh", $target, _run_as => $user)
  run_script('test/id.sh', $target, _run_as => $user)
  return run_plan(test::whoami, target => $target, _run_as => $user)
}
