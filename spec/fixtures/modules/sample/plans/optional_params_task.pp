# @summary
#   Demonstrates plans with optional parameters
#
# @param param_mandatory A mandatory parameter
# @param param_optional An optional parameter
# @param param_with_default_value A parameter with a default value
plan sample::optional_params_task(
  String $param_mandatory,
  Optional[String] $param_optional,
  String $param_with_default_value = 'foo'
) {
  'noop'
}
