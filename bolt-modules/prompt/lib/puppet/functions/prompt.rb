# frozen_string_literal: true

require 'bolt/error'

# Display a prompt and wait for a response.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:prompt) do
  # @param prompt The prompt to display.
  # @param options A hash of additional options.
  # @option options [Boolean] sensitive Disable echo back and mark the response as sensitive.
  # @return The response to the prompt.
  # @example Prompt the user if plan execution should continue
  #   $response = prompt('Continue executing plan? [Y\N]')
  # @example Prompt the user for sensitive information
  #   $password = prompt('Enter your password', 'sensitive' => true)
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

    options = options.transform_keys(&:to_sym)

    executor = Puppet.lookup(:bolt_executor)
    # Send analytics report
    executor.report_function_call(self.class.name)

    response = executor.prompt(prompt, options)

    if options[:sensitive]
      Puppet::Pops::Types::PSensitiveType::Sensitive.new(response)
    else
      response
    end
  end
end
