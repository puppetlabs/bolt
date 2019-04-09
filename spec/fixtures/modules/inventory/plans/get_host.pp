plan inventory::get_host($nodes ) {
  $target = get_targets($nodes)[0]
  return({ 'result' => $target.host})
}
