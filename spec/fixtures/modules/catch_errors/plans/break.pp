plan catch_errors::break(
  TargetSpec $nodes,
  Array $list
) {
  $list.each |$elem| {
    catch_errors() || {
      notice($elem)
      break()
      notice("Out of bounds")
    }
  }
  return "Break the chain"
}