plan background::return() {
  $future = background() || {
    return 'Return me!'
  }
  return $future.wait
}
