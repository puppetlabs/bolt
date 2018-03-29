plan facts(String $host) {
  $target = get_targets($host)[0]
  add_facts($target, { 'kernel' => 'Linux', 'cloud' => { 'provider' => 'AWS' } })
  return "Facts for ${host}: ${facts($target)}"
}
