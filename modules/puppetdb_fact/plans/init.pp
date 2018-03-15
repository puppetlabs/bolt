plan puppetdb_fact(TargetSpec $nodes) {
  $targets = get_targets($nodes)
  $certnames = $targets.map |$target| { $target.host }
  $pdb_facts = puppetdb_fact($certnames)
  $targets.each |$target| {
    add_facts($target, $pdb_facts[$target.host])
  }

  return $pdb_facts
}