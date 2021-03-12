# frozen_string_literal: true

require 'bolt/error'

# Display a prompt and wait for a response.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:prompt) do
  # @param prompt The prompt to display.
  # @param options A hash of additional options.
  # @option options [Boolean] sensitive Disable echo back and mark the response as sensitive.
  #   The returned value will be wrapped by the `Sensitive` data type. To access the raw
  #   value, use the `unwrap` function (i.e. `$sensitive_value.unwrap`).
  # @option options [String] default The default value to return if the user does not provide
  #   input or if stdin is not a tty.
  # @return The response to the prompt.
  # @example Prompt the user if plan execution should continue
  #   $response = prompt('Continue executing plan? [Y\N]')
  # @example Prompt the user for sensitive information
  #   $password = prompt('Enter your password', 'sensitive' => true)
  #   out::message("Password is: ${password.unwrap}")
  # @example Prompt the user and provide a default value
  #   $user = prompt('Enter your login username', 'default' => 'root')
  # @example Prompt the user for sensitive information, returning a sensitive default if one is not provided
  #   $token = prompt('Enter token', 'default' => lookup('default_token'), 'sensitive' => true)
  #   out::message("Token is: ${token.unwrap}")
  # @example Prompt the user and fail with a custom message if no input was provided
  #   $response = prompt('Enter your name', 'default' => '')
  #   if $response.empty {
  #     fail_plan('Must provide your name')
  #   }
  dispatch :prompt do
    param 'String', :prompt
    optional_param 'Hash[String[1], Any]', :options
    return_type 'Variant[String, Sensitive]'
  end

  def prompt(prompt, options = {})
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
                              action: 'prompt')
    end

    options  = options.transform_keys(&:to_sym)
    executor = Puppet.lookup(:bolt_executor)

    # Send analytics report
    executor.report_function_call(self.class.name)

    # Require default to be a string value
    if options.key?(:default) && !options[:default].is_a?(String)
      raise Bolt::ValidationError, "Option 'default' must be a string"
    end

    response = executor.prompt(prompt, options)

    # If sensitive, wrap it
    if options[:sensitive]
      Puppet::Pops::Types::PSensitiveType::Sensitive.new(response)
    else
      response
    end
  end
end
