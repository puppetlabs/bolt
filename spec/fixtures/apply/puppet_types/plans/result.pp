plan puppet_types::result (
  TargetSpec $targets
) {
  $target = get_target($targets)
  $target.apply_prep

  $result = run_command('whoami', $target).first

  return apply($target) {
    notify { "Result value: ${$result.value['stdout']}": }
    notify { "Result target name: ${$result.target.name}": }
  }
}
