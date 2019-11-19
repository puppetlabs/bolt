plan puppet_types::resultset (
  TargetSpec $targets
) {
  $first = get_targets($targets)[0]
  $first.apply_prep

  $result = run_command('whoami', $targets)

  return apply($first) {
    notify { "ResultSet target names: ${$result.names}": }
  }
}
