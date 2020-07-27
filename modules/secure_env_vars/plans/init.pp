plan secure_env_vars(
  TargetSpec $targets,
  Optional[String] $command = undef,
  Optional[String] $script = undef
) {
  $env_vars = parsejson(system::env('BOLT_ENV_VARS'))
  unless type($command) == Undef or type($script) == Undef {
      fail_plan('Cannot specify both script and command for secure_env_vars')
  }

  return if $command {
           run_command($command, $targets, '_env_vars' => $env_vars)
         }
         elsif $script {
           run_script($script, $targets, '_env_vars' => $env_vars)
         }
         else {
           fail_plan('Must specify either script or command for secure_env_vars')
         }
}
