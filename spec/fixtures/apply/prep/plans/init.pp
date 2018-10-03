plan prep(TargetSpec $nodes) {
  $nodes.apply_prep

  return apply($nodes) {
    notify { "Hello ${$trusted['certname']}": }
    notify { 'agent facts': message => "${clientcert}\n${fqdn}\n${clientversion}\n${puppetversion}\n${clientnoop}"}
  }
}
