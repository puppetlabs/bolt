plan wait::no_future::infinite_loop() {
  background("infinite loop") || {
    wait()
  }
}
