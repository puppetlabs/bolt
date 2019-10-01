plan resource_types(TargetSpec $nodes){
  # Reference built-in type
  $package = get_resources($nodes, User).to_data[0]['status']
  # Reference core type 
  $cron = get_resources($nodes, Cron).to_data[0]['status']
  # Reference custom type
  $mytype = get_resources($nodes, My_type).to_data[0]['status']

  $result = { 'built-in' => $package, 'core' => $cron, 'custom' => $mytype }

  return $result
}
