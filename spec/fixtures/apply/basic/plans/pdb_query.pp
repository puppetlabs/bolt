plan basic::pdb_query(TargetSpec $nodes) {
  return apply($nodes) {
    $certs = puppetdb_query('nodes[certname] {}')
    notify { "found ${certs}": }
  }
}
