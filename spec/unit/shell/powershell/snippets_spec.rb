# frozen_string_literal: true

require 'spec_helper'
require 'base64'
require 'json'
require 'bolt/shell/powershell/snippets'

describe Bolt::Shell::Powershell::Snippets do
  subject { described_class }

  describe '.execute_process' do
    it 'returns a PowerShell script string containing the command' do
      result = subject.execute_process('Write-Host hello')
      expect(result).to include('Write-Host hello')
    end

    it 'includes UTF-8 encoding setup' do
      result = subject.execute_process('mycommand')
      expect(result).to include('UTF8Encoding')
    end

    it 'includes exit code handling' do
      result = subject.execute_process('mycommand')
      expect(result).to include('exit $LASTEXITCODE')
    end
  end

  describe '.exit_with_code' do
    it 'returns a PowerShell script containing the command' do
      result = subject.exit_with_code('Invoke-Something')
      expect(result).to include('Invoke-Something')
    end

    it 'includes exit code handling' do
      result = subject.exit_with_code('mycommand')
      expect(result).to include('exit $LASTEXITCODE')
    end
  end

  describe '.make_tmpdir' do
    it 'returns a PowerShell script to create a temp directory under the given parent' do
      result = subject.make_tmpdir('$env:TEMP')
      expect(result).to include('$env:TEMP')
      expect(result).to include('New-Item')
    end
  end

  describe '.rmdir' do
    it 'returns a PowerShell script to remove the given directory' do
      result = subject.rmdir('C:\\temp\\bolt-abc')
      expect(result).to include('Remove-Item')
      expect(result).to include('C:\\temp\\bolt-abc')
    end
  end

  describe '.run_script' do
    it 'returns a PowerShell script to run a script file' do
      result = subject.run_script([], 'C:\\scripts\\myscript.ps1')
      expect(result).to include('C:\\scripts\\myscript.ps1')
      expect(result).to include('Invoke-Command')
    end

    it 'includes arguments in the script' do
      result = subject.run_script(%w[arg1 arg2], 'C:\\scripts\\myscript.ps1')
      expect(result).to include('arg1')
      expect(result).to include('arg2')
    end
  end

  describe '.append_ps_module_path' do
    it 'returns a PowerShell script to append the module path' do
      result = subject.append_ps_module_path('C:\\modules')
      expect(result).to include('C:\\modules')
      expect(result).to include('PSModulePath')
    end
  end

  describe '.ps_task' do
    it 'returns a PowerShell script to run a task with arguments' do
      args = { 'param1' => 'value1' }
      result = subject.ps_task('C:\\tasks\\mytask.ps1', args)
      expect(result).to include('C:\\tasks\\mytask.ps1')
      # Arguments should be base64 encoded
      expected_b64 = Base64.encode64(JSON.dump(args))
      expect(result).to include(expected_b64.strip)
    end
  end

  describe '.try_catch' do
    it 'returns a PowerShell try-catch expression' do
      result = subject.try_catch('mycommand.exe')
      expect(result).to include('mycommand.exe')
      expect(result).to include('try')
      expect(result).to include('catch')
    end
  end

  describe '.shell_init' do
    it 'returns a PowerShell initialization script that sets Puppet path' do
      result = subject.shell_init
      expect(result).to include('Puppet Labs')
    end

    it 'includes the ConvertFrom-PSCustomObject function' do
      result = subject.shell_init
      expect(result).to include('ConvertFrom-PSCustomObject')
    end

    it 'includes the Get-ContentAsJson function' do
      result = subject.shell_init
      expect(result).to include('Get-ContentAsJson')
    end
  end
end
