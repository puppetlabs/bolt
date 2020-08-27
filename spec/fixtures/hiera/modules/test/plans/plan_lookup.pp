plan test::plan_lookup(
  TargetSpec $targets
) {
  $outside_apply = lookup('pop')
  $in_apply = apply($targets) {
    notify { lookup('pop'): }
  }
  $a = { 'outside_apply' => $outside_apply,
         'in_apply' => $in_apply.first.report['resource_statuses'] }
  return $a
}
