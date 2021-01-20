plan basic::collisions(
  TargetSpec $targets
) {
  $target = get_target($targets)

  $target.add_facts(
    'fact_plan'   => '',
    'fact_target' => ''
  )

  $target.set_var('fact_target', '')
  $target.set_var('plan_target', '')

  $fact_plan   = ''
  $plan_target = ''

  return apply($target) {
    notice('Collisions everywhere!')
  }
}
