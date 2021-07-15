# frozen_string_literal: true

require 'bolt/logger'

# Wait for a Future or array of Futures to finish and return results,
# optionally with a timeout.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:wait, Puppet::Functions::InternalFunction) do
  # Wait for Futures to finish.
  # @param futures A Bolt Future object or array of Bolt Futures to wait on.
  # @param options A hash of additional options.
  # @option options [Boolean] _catch_errors Whether to catch raised errors.
  # @return A Result or Results from the Futures
  # @example Upload a large file in the background, then wait until it's loaded
  #   $futures = background() || {
  #     upload_file("./very_large_file", "/opt/jfrog/artifactory/var/etc/artifactory", $targets)
  #   }
  #   # Run an unrelated task
  #   run_task("deploy", $targets)
  #   # Wait for the file upload to finish
  #   $results = wait($futures)
  dispatch :wait do
    param 'Variant[Future, Array[Future]]', :futures
    optional_param 'Hash[String[1], Any]', :options
    return_type 'Array[Boltlib::PlanResult]'
  end

  # Wait for all Futures in the current plan to finish.
  # @param options A hash of additional options.
  # @option options [Boolean] _catch_errors Whether to catch raised errors.
  # @return A Result or Results from the Futures
  # @example Perform multiple tasks in the background, then wait for all of them to finish
  #   background() || { upload_file("./large_file", "/opt/jfrog/...", $targets) }
  #   background() || { run_task("db::migrate", $targets) }
  #   # Wait for all futures in the plan to finish and return all results
  #   $results = wait()
  dispatch :wait_for_all do
    optional_param 'Hash[String[1], Any]', :options
    return_type 'Array[Boltlib::PlanResult]'
  end

  # Wait for all Futures in the current plan to finish with a timeout.
  # @param timeout How long to wait for Futures to finish before raising a Timeout error.
  # @param options A hash of additional options.
  # @option options [Boolean] _catch_errors Whether to catch raised errors.
  # @return A Result or Results from the Futures
  # @example Perform multiple tasks in the background, then wait for all of them to finish with a timeout
  #   background() || { upload_file("./large_file", "/opt/jfrog/...", $targets) }
  #   background() || { run_task("db::migrate", $targets) }
  #   # Wait for all futures in the plan to finish and return all results
  #   $results = wait(30)
  dispatch :wait_for_all_with_timeout do
    param 'Variant[Integer[0], Float[0.0]]', :timeout
    optional_param 'Hash[String[1], Any]', :options
    return_type 'Array[Boltlib::PlanResult]'
  end

  # Wait for Futures to finish with timeout.
  # @param futures A Bolt Future object or array of Bolt Futures to wait on.
  # @param timeout How long to wait for Futures to finish before raising a Timeout error.
  # @param options A hash of additional options.
  # @option options [Boolean] _catch_errors Whether to catch raised errors.
  # @return A Result or Results from the Futures
  # @example Upload a large file in the background with a 30 second timeout.
  #   $futures = background() || {
  #     upload_file("./very_large_file", "/opt/jfrog/artifactory/var/etc/artifactory", $targets)
  #   }
  #   # Run an unrelated task
  #   run_task("deploy", $targets)
  #   # Wait for the file upload to finish
  #   $results = wait($futures, 30)
  #
  # @example Upload a large file in the background with a 30 second timeout, catching any errors.
  #   $futures = background() || {
  #     upload_file("./very_large_file", "/opt/jfrog/artifactory/var/etc/artifactory", $targets)
  #   }
  #   # Run an unrelated task
  #   run_task("deploy", $targets)
  #   # Wait for the file upload to finish
  #   $results = wait($futures, 30, '_catch_errors' => true)
  dispatch :wait_with_timeout do
    param 'Variant[Future, Array[Future]]', :futures
    param 'Variant[Integer[0], Float[0.0]]', :timeout
    optional_param 'Hash[String[1], Any]', :options
    return_type 'Array[Boltlib::PlanResult]'
  end

  def wait(futures, options = {})
    inner_wait(futures: futures, options: options)
  end

  def wait_for_all(options = {})
    inner_wait(options: options)
  end

  def wait_for_all_with_timeout(timeout, options = {})
    inner_wait(timeout: timeout, options: options)
  end

  def wait_with_timeout(futures, timeout, options = {})
    inner_wait(futures: futures, timeout: timeout, options: options)
  end

  def inner_wait(futures: nil, timeout: nil, options: {})
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'wait')
    end

    valid, unknown = options.partition { |k, _v| %w[_catch_errors].include?(k) }.map(&:to_h)
    if unknown.any?
      file, line = Puppet::Pops::PuppetStack.top_of_stack
      msg = "The wait() function call in #{file}#L#{line} received unknown options "\
        "#{unknown.keys}. Removing unknown options and continuing..."
      Bolt::Logger.warn("plan_function_options", msg)
    end

    valid = valid.transform_keys { |k| k.sub(/^_/, '').to_sym }
    valid[:timeout] = timeout if timeout

    executor = Puppet.lookup(:bolt_executor)
    executor.report_function_call(self.class.name)

    # If we get a single Future, make sure it's an array. If we didn't get any
    # futures pass that on to wait so we can continue collecting any futures
    # that are created while waiting on existing futures.
    futures = Array(futures) unless futures.nil?
    executor.wait(futures, **valid)
  end
end
