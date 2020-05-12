# A PlanResult describes the supported return values of a plan. It
# should be used as the return type of functions that run plans and return the
# results.

type Boltlib::PlanResult = Variant[Boolean, 
                                   Numeric,
                                   String,
                                   Undef,
                                   Error,
                                   Result,
                                   ApplyResult,
                                   ResultSet,
                                   Target,
                                   Array[Boltlib::PlanResult],
                                   Hash[String, Boltlib::PlanResult]]
