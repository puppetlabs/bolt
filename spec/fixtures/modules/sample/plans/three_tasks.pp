plan app::deployment (
  String $app_version
) {

  # disable app hosts in $tier from lb
  run_task(gce::lb_disable, $nodes["loadbalancers"],
    real_servers => $nodes["app_hosts"],
  )

  # deploy the app!
  run_task(app::deploy, $nodes["app_hosts"],
    version => $app_version,
  )

  # revisit the load balancers and re-enable the app hosts 
  run_task(gce::lb_enable, $nodes["loadbalancers"],
    real_servers => $nodes["app_hosts"],    
  )

}  

