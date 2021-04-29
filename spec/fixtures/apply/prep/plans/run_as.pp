plan prep::run_as(TargetSpec $targets) {
  apply_prep($targets, '_run_as' => 'root')

  return apply($targets) {
    notify { "Hello ${$trusted['certname']}": }
    notify { 'agent facts': message => "${clientcert}\n${fqdn}\n${clientversion}\n${puppetversion}\n${clientnoop}"}
  }
}
