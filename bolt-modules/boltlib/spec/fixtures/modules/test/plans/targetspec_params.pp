plan test::targetspec_params(
  Boltlib::TargetSpec $ts,
  Optional[Boltlib::TargetSpec] $optional_ts,
  Variant[Boltlib::TargetSpec, String] $variant_ts,
  Array[Boltlib::TargetSpec] $array_ts,
  Variant[Array[Boltlib::TargetSpec], String] $nested_ts,
  String $string,
  $typeless,
){
  return get_targets('all').map |$n| { $n.safe_name }
}
