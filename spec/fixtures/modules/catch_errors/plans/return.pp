plan catch_errors::return(TargetSpec $nodes) {
  $message = catch_errors() || {
    return "You can return a product for up to 30 days from the date you purchased it"
    notice("Don't go here")
  }
  return "Never break the chain"
}