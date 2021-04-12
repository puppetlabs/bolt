plan background::timing() {
  $future = background() || {
    out::message("Starting backgrounded block")
  }
  out::message("Returned immediately")
  out::message("Type of $future")
}
