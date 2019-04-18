plan add_group (TargetSpec $nodes) {
  $new_target = Target.new(
    "0.0.0.0:20024",
    "host-key-check" => false,
    "user" => 'bolt',
    'password' => 'bolt'
  )

  # Add new facts/var, specifically one that is novel, the other that should override existing.
  $new_target.add_facts({'plan_context' => 'keep', 'override_parent' => 'keep'})
  $new_target.set_var('plan_context','keep')
  $new_target.set_var('override_parent', 'keep')
  # Add from Target object
  $new_target.add_to_group('add_me')
  # When a Target already exists in a group, do nothing (bar_1 defined in bar)
  add_to_group('bar_1', 'bar')
  # Add to default "all" group
  add_to_group('add_to_all', 'all')
  $add_me_targets = get_targets('add_me')

  $result = { 
    'addme_group' => $add_me_targets,
    'existing_facts' => $add_me_targets[0].facts,
    'existing_vars' => $add_me_targets[0].vars,
    'added_facts' => $add_me_targets[1].facts,
    'added_vars' => $add_me_targets[1].vars,
    'target_not_overwritten' => get_targets('bar')[0].vars['bar_1_var'],
    'target_not_duplicated' => get_targets('bar'),
    'target_to_all_group' => get_targets('all')
  }

  return $result
}
