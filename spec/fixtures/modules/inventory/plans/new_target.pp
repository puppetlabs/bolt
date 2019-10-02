plan inventory::new_target(Hash $new_target_hash) {
  # Start with empty all group and add a new target using get_target
  $transport = $new_target_hash['transport']
  $user = $new_target_hash[$transport]['user']
  $password = $new_target_hash[$transport]['password']
  $host = $new_target_hash[$transport]['host']
  $port = $new_target_hash[$transport]['port']
  $uri = "${transport}://${user}:${password}@${host}:${port}"
  $new_target_from_uri = get_target($uri)
  $expected_host_key_fail = run_command('whoami', get_targets('all'), '_catch_errors' => true)
  # Add a new target using Target.new 
  $new_target_from_target_new = Target.new({ 'name' => 'new_target', 'config' => $new_target_hash })
  # Update config for target created from uri with get_target
  $new_target_from_uri.set_config(['ssh', 'host-key-check'], false)
  $expected_success = run_command('whoami', get_targets('all'))
  $result = { 'expected_host_key_fail' => $expected_host_key_fail, 'expected_success' => $expected_success }
  return $result
}
