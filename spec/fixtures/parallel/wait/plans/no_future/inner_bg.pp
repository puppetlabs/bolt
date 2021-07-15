plan wait::no_future::inner_bg() {
  background() || {
    background() || {
      return "Thing 2"
    }
    return "Thing 1"
  }
  return wait()
}
