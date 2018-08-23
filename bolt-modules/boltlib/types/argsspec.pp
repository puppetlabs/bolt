# SensitiveData represent the acceptable types to pass as arguments into the run_xxx()
# functions:
#   - run_script()
#   - run_plan()
#   - run_task()
#
# @note this is simply module Puppet::Pops::Loader::StaticLoader::BUILTIN_ALIASES['Data']
#       but it also has Sensitive within it and also does recursion with itself instead of the
#       Data alias (necessary for nested Sensitive types)
type Boltlib::ArgsSpec = Variant[Sensitive[Boltlib::ArgsSpec], ScalarData, Undef, Hash[String, Boltlib::ArgsSpec], Array[Boltlib::ArgsSpec]]
