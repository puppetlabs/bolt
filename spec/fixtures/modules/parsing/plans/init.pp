plan parsing(
  String $string,
  Variant[String, Boolean] $string_bool,
  TargetSpec $nodes,
  Optional[Array] $array = undef,
  Optional[Hash] $hash = undef,
) {

  $parsed_nodes = get_targets($nodes).map |$t| { $t.name }

  return({ 'string' => $string,
    'string_bool' => $string_bool,
    'nodes' => $parsed_nodes,
    'array' => $array,
    'hash' => $hash,
  })
}
