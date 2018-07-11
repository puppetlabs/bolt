plan basic::error(TargetSpec $nodes) {
  return apply($nodes) {
    debug('Debugging')
    info('Meh')
    notice('Helpful')
    warning('Warned')
    err('Fire')
    alert('Stop')
    crit('Drop')
    emerg('Roll')
  }
}
