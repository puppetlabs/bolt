plan error::catch_plan {
  $foo = Error['oops']
 run_plan('error::err', '_catch_errors' => true)
}
