plan basic::inventory_lookup(TargetSpec $nodes) {
  # add a fact durring plan execution
  $target = get_targets('all')
  add_facts($target[1], {'added' => 'fact'})

  return apply($nodes) {
  	$t = get_targets('all')
    # Number of targets queried from inventory
    notify { "Num Targets: ${$t.length}": }
    # Facts from target (should include added fact)
    notify { "Target 1 Facts: ${$t[1].facts}": }
    # Vars from target
    notify { "Target 1 Vars: ${$t[1].vars}": }
    # Prove config is respected (tty set to 11 in config) 
    notify { "Target 0 Config: ${$t[0].options}": }
    # Prove inventory config is respected (password set to 'secret' in inventoryfile)
    notify { "Target 1 Password: ${$t[1].password}": }
  }
}
