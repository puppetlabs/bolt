# A TargetSpec represents any String, Target or combination thereof that can be
# passed to get_targets() to return an Array[Target]. Generally, users
# shouldn't need to worry about the distinction between TargetSpec and
# Target/Array[Target], since the run_* functions will all handle them both
# automatically. But for use cases that need to deal with the exact list of
# Targets that will be used, get_targets() will return that.
type Boltlib::TargetSpec = Variant[String[1], Target, Array[Boltlib::TargetSpec]]
