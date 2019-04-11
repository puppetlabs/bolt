# frozen_string_literal: true

require 'bolt_command_helper'

test_name "bolt tasks should run on the local transport" do
  extend Acceptance::BoltCommandHelper

  # From spec/bolt/transport/shared_examples
  def posix_context
    {
      tmpdir: '/tmp',
      supported_req: 'shell',
      extension: '.sh',
      env_task: "#!/bin/sh\nprintenv PT_message_one\nprintenv PT_message_two",
      stdin_task: "#!/bin/sh\ncat"
    }
  end

  def windows_context
    {
      tmpdir: 'C:/mytmp',
      supported_req: 'powershell',
      extension: '.ps1',
      env_task: "Write-Output \"${env:PT_message_one}\n${env:PT_message_two}\"",
      stdin_task: "$line = [Console]::In.ReadLine()\nWrite-Output \"$line\""
    }
  end

  os_context = if bolt.platform =~ /windows/
                 windows_context
               else
                 posix_context
               end

  dir = bolt.tmpdir('locomoco')
  modulepath = File.join(dir, 'modules', 'test')
  taskname = "echo#{os_context[:extension]}"
  task_metadata = JSON.generate({ 'input_method' => 'environment' })

  step 'with task that reads env vars' do
    step 'create task on bolt controller' do
      on(bolt, "mkdir -p #{File.join(modulepath, 'tasks')}")
      create_remote_file(bolt, File.join(modulepath, 'tasks', taskname), os_context[:env_task])
      create_remote_file(bolt, File.join(modulepath, 'tasks', 'echo.json'), task_metadata)
    end

    step 'execute `bolt task run` locally' do
      task = "test::echo"
      params = "message_one=beep message_two=boop"
      flags = {
        '--nodes' => 'localhost',
        '--modulepath' => File.join(dir, 'modules')
      }

      result = bolt_command_on(bolt, "bolt task run #{task} #{params}", flags)
      assert_match(/Successful on 1 node: localhost/, result.stdout, "Unexpected output from the command:\n#{result.cmd}")
      assert_match(/beep\n  boop/, result.stdout, "Unexpected output from the command:\n#{result.cmd}")
      assert(result.exit_code == 0, "#{result.cmd} exited #{result.exit_code} with stderr: #{result.stderr}")
    end
  end

  unless bolt.platform =~ /windows/
    user = 'nopass'
    step 'as a user without a password' do
      step 'create user who can escalate without password' do
        on(bolt, "/opt/puppetlabs/bolt/bin/puppet resource user #{user} ensure=present")

        teardown do
          on(bolt, "/opt/puppetlabs/bolt/bin/puppet resource user #{user} ensure=absent")
        end 
      end

      step 'set sudo user settings' do
        create_remote_file(bolt, "/etc/sudoers.d/#{user}", <<~FILE)
        Defaults:root !requiretty
        nopass ALL=(ALL) NOPASSWD: ALL
        FILE

        teardown do
          on(bolt, "rm /etc/sudoers.d/#{user}")
        end 
      end

      step 'create plan on bolt controller' do
        on(bolt, "#{os_context[:mkdir]} #{File.join(modulepath, 'plans')}")
        plan =<<~PLAN
        plan test {
          return run_command('whoami', 'localhost', '_run_as' => 'root')
        }
        PLAN
        create_remote_file(bolt, File.join(modulepath, 'plans', 'init.pp'), plan)
      end

      step 'run plan as user who does not require password' do
        bolt_command = "bolt plan run test"
        flags = { '--modulepath' => "#{dir}/modules" }

        result = bolt_command_on(bolt, bolt_command, flags)
        assert_match(/Successful on 1 node: localhost/, result.stdout, "Unexpected output from the command:\n#{result.cmd}")
        assert_match(/root/, result.stdout, "Unexpected output from the command:\n#{result.cmd}")
        assert(result.exit_code == 0, "#{result.cmd} exited #{result.exit_code} with stderr: #{result.stderr}")
      end
    end
  end
end
