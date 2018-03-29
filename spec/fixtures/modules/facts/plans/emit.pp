plan facts::emit(String $host) {
  $target = get_targets($host)[0]
  return "Facts for ${host}: ${facts($target)}"
}
