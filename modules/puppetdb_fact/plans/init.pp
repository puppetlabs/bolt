plan puppetdb_fact(TargetSpec $targets) {
  $targs = get_targets($targets)
  $certnames = $targs.map |$target| { $target.host }
  $pdb_facts = puppetdb_fact($certnames)
  $targs.each |$target| {
    add_facts($target, $pdb_facts[$target.host])
  }

  return $pdb_facts
}
