plan error::nested {
  $err = run_plan('error::err', '_catch_errors' => true);
  return({ 'error' => [ $err ] })
}
