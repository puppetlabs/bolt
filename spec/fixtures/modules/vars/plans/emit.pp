plan vars::emit(String $host) {
  $target = get_targets($host)[0]
  return "Vars for ${host}: ${$target.vars}"
}
