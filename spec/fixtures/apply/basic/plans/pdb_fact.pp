plan basic::pdb_fact(TargetSpec $nodes) {
  return apply($nodes) {
    $facts = puppetdb_fact(['foo'])
    notify { "found ${facts}": }
  }
}
