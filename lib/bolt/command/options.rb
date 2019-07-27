# frozen_string_literal: true

require 'optparse'

module Bolt
  class BoltOptionParser < OptionParser
    def self.examples(cmd, desc)
      <<~EXAMP
      #{desc} a Windows host via WinRM, providing for the password
        bolt #{cmd} -n winrm://winhost -u Administrator -p
      #{desc} the local machine, a Linux host via SSH, and hosts from a group specified in an inventory file
        bolt #{cmd} -n localhost,nixhost,node_group
      #{desc} Windows hosts queried from PuppetDB via WinRM as a domain user, prompting for the password
        bolt #{cmd} -q 'inventory[certname] { facts.os.family = "windows" }' --transport winrm -u 'domain\\Administrator' -p
      EXAMP
    end

    # rubocop:disable Layout/AlignHash
    BANNER = {
      'default'     => <<~HELP,
                       Usage: bolt <subcommand> <action>

                       Available subcommands:
                          apply <manifest>                  Apply Puppet manifest code
                          command run <command>             Run a command remotely
                          file upload <src> <dest>          Upload a local file or directory
                          inventory show                    Show the list of targets an action would run on
                          plan convert <plan_path>          Convert a YAML plan to a Puppet plan
                          plan show                         Show list of available plans
                          plan show <plan>                  Show details for plan
                          plan run <plan> [params]          Run a Puppet task plan
                          puppetfile install                Install modules from a Puppetfile into a Boltdir
                          puppetfile show-modules           List modules available to Bolt
                          script run <script>               Upload a local script and run it remotely
                          secret createkeys                 Create new encryption keys
                          secret encrypt <plaintext>        Encrypt a value
                          secret decrypt <encrypted>        Decrypt a value
                          task show                         Show list of available tasks
                          task show <task>                  Show documentation for task
                          task run <task> [params]          Run a Puppet task

                       Run `bolt <subcommand> --help` to view specific examples.
                       HELP
      'apply'       => <<~HELP,
                       Usage: bolt apply <manifest.pp>

                       bolt apply site.pp --nodes foo.example.com,bar.example.com

                       #{examples('apply site.pp', 'apply a manifest on')}
                       Options:
                       HELP
      'command'     => <<~HELP,
                       Usage: bolt command <action> <command>

                       Available actions are:
                           run                              Run a command remotely

                       #{examples('command run hostname', 'run hostname on')}
                       HELP
      'command run' => <<~HELP,
                       Usage: bolt command run <command>

                       bolt command run uptime --targets foo,bar
                       HELP
      'file'        => <<~HELP,
                       Usage: bolt file <action>

                       Available actions are:
                           upload <src> <dest>     Upload local file or directory <src> to <dest> on each node

                       #{examples('file upload /tmp/source /etc/profile.d/login.sh', 'upload a file to')}
                       HELP
      'inventory'   => <<~HELP,
                       Usage: bolt inventory <action>

                       Available actions are:
                           show                     Show the list of targets an action would run on
                       HELP
      'plan'        => <<~HELP,
                       Usage: bolt plan <action> <plan> [parameters]

                       Available actions are:
                           convert <plan_path>              Convert a YAML plan to a Puppet plan
                           show                             Show list of available plans
                           show <plan>                      Show details for plan
                           run                              Run a Puppet task plan

                       Parameters are of the form <parameter>=<value>.

                       #{examples('plan run canary command=hostname', 'run the canary plan on')}
                       HELP
      'plan convert' => <<~HELP,
                       Usage: bolt plan convert <plan_path>
                       HELP
      'plan run'    => <<~HELP,
                       Usage: bolt plan run <plan> [parameters]

                       Parameters are of the form <parameter>=<value>.

                       #{examples('plan run canary command=hostname', 'run the canary plan on')}
                       HELP
      'plan show'   => <<~HELP,
                       Usage: bolt plan show <plan>

                       Available actions are:
                           show                             Show list of available plans
                           show <plan>                      Show details for plan
                       HELP
      'puppetfile'  => <<~HELP,
                       Usage: bolt puppetfile <action>

                       Available actions are:
                           install                          Install modules from a Puppetfile into a Boltdir
                           show-modules                     List modules available to Bolt

                       Install modules into the local Boltdir
                         bolt puppetfile install
                       HELP
      'puppetfile install' => <<~HELP,
                       Usage: bolt puppetfile install

                       Available actions are:
                           bolt puppetfile install          Install modules into the boltdir
                       HELP
      'puppetfile show-modules' => <<~HELP,
                       Usage: bolt puppetfile show-modules
                       HELP
      'script'      => <<~HELP,
                       Usage: bolt script <action> <script> [[arg1] ... [argN]]

                       Available actions are:
                           run                              Upload a local script and run it remotely

                       #{examples('script run my_script.ps1 some args', 'run a script on')}
                       HELP
      'secret'      => <<~HELP,
                       Manage secrets for inventory and hiera data.

                       Available actions are:
                           createkeys                       Create new encryption keys
                           encrypt                          Encrypt a value
                           decrypt                          Decrypt a value
                       HELP
      'task'        => <<~HELP,
                       Usage: bolt task <action> <task> [parameters]

                       Available actions are:
                           show                             Show list of available tasks
                           show <task>                      Show documentation for task
                           run <task>                       Run a Puppet task

                       Parameters are of the form <parameter>=<value>.

                       #{examples('task run facts', 'run facter on')}
                       HELP
      'task run'    => <<~HELP,
                       Usage: bolt task run <task> [parameters]

                       Parameters are of the form <parameter>=<value>.

                       #{examples('task run facts', 'run facter on')}
                       HELP
      'task show'   => <<~HELP
                       Usage: bolt task show <task>

                       Available actions are:
                           show                             Show list of available tasks
                           show <task>                      Show documentation for task
                       HELP
    }.freeze
    # rubocop:enable Layout/AlignHash
  end
end
