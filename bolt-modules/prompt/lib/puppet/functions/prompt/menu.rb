# frozen_string_literal: true

require 'bolt/error'

# Display a menu prompt and wait for a response. Continues to prompt
# until an option from the menu is selected.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:'prompt::menu') do
  # Select from a list of options.
  # @param prompt The prompt to display.
  # @param menu A list of options to choose from.
  # @param options A hash of additional options.
  # @option options [String] default The default option to return if the user does not provide
  #   input or if stdin is not a tty. Must be an option present in the menu.
  # @return The selected option.
  # @example Prompt the user to select from a list of options
  #   $selection = prompt::menu('Select a fruit', ['apple', 'banana', 'carrot'])
  # @example Prompt the user to select from a list of options with a default value
  #   $selection = prompt::menu('Select environment', ['development', 'production'], 'default' => 'development')
  dispatch :prompt_menu_array do
    param 'String', :prompt
    param 'Array[Variant[Target, Data]]', :menu
    optional_param 'Hash[String[1], Variant[Target, Data]]', :options
    return_type 'Variant[Target, Data]'
  end

  # Select from a list of options with custom inputs.
  # @param prompt The prompt to display.
  # @param menu A hash of options to choose from, where keys are the input used to select a value.
  # @param options A hash of additional options.
  # @option options [String] default The default option to return if the user does not provide
  #   input or if stdin is not a tty. Must be an option present in the menu.
  # @return The selected option.
  # @example Prompt the user to select from a list of options with custom inputs
  #   $menu = { 'y' => 'yes', 'n' => 'no' }
  #   $selection = prompt::menu('Install Puppet?', $menu)
  dispatch :prompt_menu do
    param 'String', :prompt
    param 'Hash[String[1], Variant[Target, Data]]', :menu
    optional_param 'Hash[String[1], Variant[Target, Data]]', :options
    return_type 'Variant[TargetSpec, Data]'
  end

  def prompt_menu_array(prompt, menu, options = {})
    menu_hash = menu.map.with_index { |value, index| [(index + 1).to_s, value] }.to_h
    prompt_menu(prompt, menu_hash, options)
  end

  def prompt_menu(prompt, menu, options = {})
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
                              action: 'prompt::menu')
    end

    options  = options.transform_keys(&:to_sym)
    executor = Puppet.lookup(:bolt_executor)

    # Send analytics report
    executor.report_function_call(self.class.name)

    # Error if there are no options
    if menu.empty?
      raise Bolt::ValidationError, "Menu cannot be empty"
    end

    # Error if the default value is not on the menu
    if options.key?(:default) && !menu.value?(options[:default])
      raise Bolt::ValidationError, "Default value '#{options[:default]}' is not one of the provided menu options"
    end

    # The first prompt should include the menu
    to_prompt = format_menu(menu) + prompt

    # Request input from the user until they provide a valid option
    loop do
      selection = executor.prompt(to_prompt, options)

      return menu[selection] if menu.key?(selection)
      return selection       if options.key?(:default) && options[:default] == selection

      # Only reprint the prompt, not the menu
      to_prompt = "Invalid option, try again. #{prompt}"
    end
  end

  # Builds the menu string. Aligns all the values by padding input keys.
  #
  private def format_menu(menu)
    # Find the longest input and add 2 for wrapping parenthesis
    key_length = menu.keys.max_by(&:length).length + 2

    menu_string = +''

    menu.each do |key, value|
      key = "(#{key})".ljust(key_length)
      menu_string << "#{key} #{value}\n"
    end

    menu_string
  end
end
