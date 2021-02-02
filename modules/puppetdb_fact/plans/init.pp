# @summary
#   Collect facts for the specified targets from PuppetDB and store them
#   on the Targets.
#
# This plan accepts a list of targets to collect facts for from the configured
# PuppetDB connection. After collecting facts, they are stored on each target's
# Target object. The updated facts can then be accessed using `$target.facts`.
#
# @param targets
#   The targets to collect facts for.
plan puppetdb_fact(TargetSpec $targets) {
  $targs = get_targets($targets)
  $certnames = $targs.map |$target| { $target.host }
  $pdb_facts = puppetdb_fact($certnames)
  $targs.each |$target| {
    add_facts($target, $pdb_facts[$target.host])
  }

  return $pdb_facts
}
