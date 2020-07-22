plan env_var::command(
  TargetSpec $targets,
  String $user
) {
  $vars = { 'chips' => 'and guacamole' }
  return run_command('echo $chips', $targets, '_env_vars' => $vars, '_run_as' => $user)
}
