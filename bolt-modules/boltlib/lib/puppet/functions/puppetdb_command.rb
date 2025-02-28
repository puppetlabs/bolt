# frozen_string_literal: true

require 'bolt/error'

# Send a command with a payload to PuppetDB.
#
# The `pdb_command` function only supports version 5 of the `replace_facts`
# command. Other commands might also work, but are not tested or supported
# by Bolt.
#
# See the [commands endpoint](https://puppet.com/docs/puppetdb/latest/api/command/v1/commands.html)
# documentation for more information about available commands and payload
# format.
#
# _This function is experimental and subject to change._
#
# > **Note:** Not available in apply block
#
Puppet::Functions.create_function(:puppetdb_command) do
  # Send a command with a payload to PuppetDB.
  #
  # @param command The command to invoke.
  # @param version The version of the command to invoke.
  # @param payload The payload to the command.
  # @return The UUID identifying the response sent by PuppetDB.
  # @example Replace facts for a target
  #   $payload = {
  #     'certname'           => 'localhost',
  #     'environment'        => 'dev',
  #     'producer'           => 'bolt',
  #     'producer_timestamp' => '1970-01-01',
  #     'values'             => { 'orchestrator' => 'bolt' }
  #   }
  #
  #   puppetdb_command('replace_facts', 5, $payload)
  dispatch :puppetdb_command do
    param 'String[1]', :command
    param 'Integer', :version
    param 'Hash[Data, Data]', :payload
    return_type 'String'
  end

  # Send a command with a payload to a named PuppetDB instance.
  #
  # @param command The command to invoke.
  # @param version The version of the command to invoke.
  # @param payload The payload to the command.
  # @param instance The PuppetDB instance to send the command to.
  # @return The UUID identifying the response sent by PuppetDB.
  # @example Replace facts for a target using a named PuppetDB instance
  #   $payload = {
  #     'certname'           => 'localhost',
  #     'environment'        => 'dev',
  #     'producer'           => 'bolt',
  #     'producer_timestamp' => '1970-01-01',
  #     'values'             => { 'orchestrator' => 'bolt' }
  #   }
  #
  #   puppetdb_command('replace_facts', 5, $payload, 'instance-1')
  dispatch :puppetdb_command_with_instance do
    param 'String[1]', :command
    param 'Integer', :version
    param 'Hash[Data, Data]', :payload
    param 'String', :instance
    return_type 'String'
  end

  def puppetdb_command(command, version, payload)
    puppetdb_command_with_instance(command, version, payload, nil)
  end

  def puppetdb_command_with_instance(command, version, payload, instance)
    # Disallow in apply blocks.
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
        action: 'puppetdb_command'
      )
    end

    # Send analytics report.
    Puppet.lookup(:bolt_executor).report_function_call(self.class.name)

    puppetdb_client = Puppet.lookup(:bolt_pdb_client)

    # Error if the PDB client does not implement :send_command
    unless puppetdb_client.respond_to?(:send_command)
      raise Bolt::Error.new(
        "PuppetDB client #{puppetdb_client.class} does not implement :send_command, " \
        "unable to invoke command.",
        'bolt/pdb-command'
      )
    end

    puppetdb_client.send_command(command, version, payload, instance)
  end
end
