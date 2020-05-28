plan sensitive (
  Sensitive $array,
  Sensitive $hash,
  Sensitive $string
) {
  $result = {
    'array'  => $array.unwrap,
    'hash'   => $hash.unwrap,
    'string' => $string.unwrap
  }

  return $result
}
