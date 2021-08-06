# Invoke a custom Puppet language function that invokes an executor function
# within a parallelize block. The $target variable should not be removed from
# the scope after the custom function is invoked.
plan parallel::custom_function () {
  $target = 'localhost'

  parallelize([1, 2]) |$i| {
    parallel::custom_function($target)
  }

  return $target
}
