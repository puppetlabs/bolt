plan basic::fact_merge(
  TargetSpec $targets,
) {
  $targetspec = get_targets($targets)

  $fresh = 'air'
  $os = 'mosis'
  $targetspec.each |$t| { $t.set_var('fresh', 'start') }
  $targetspec.each |$t| {
    add_facts($t, { 'fresh' => 'strawberries' })
  }

  return apply($targetspec) {
    notify { "Fresh ${$fresh}": }
    notify { "${$os}": }
  }
}
