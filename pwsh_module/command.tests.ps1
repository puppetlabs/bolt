Import-Module -Name (Join-Path (Split-Path $PSCommandPath) 'PuppetBolt' 'PuppetBolt.psd1') -Force
BeforeAll {

  Mock -ModuleName 'PuppetBolt' -Verifiable -CommandName Invoke-BoltCommandLine -MockWith {
    return "bolt " + $params -join " "
  }

  Mock Get-ItemProperty {
    return [PSCustomObject]@{
      RememberedInstallDir = 'C:/Program Files/Puppet Labs/Bolt'
    }
  }

  $common = @(
    'Version', 'Debug', 'ErrorAction', 'ErrorVariable', 'InformationAction',
    'InformationVariable', 'OutBuffer',  'OutVariable', 'PipelineVariable',
    'Verbose', 'WarningAction', 'WarningVariable', 'Confirm', 'Whatif'
  )
}

Describe "test bolt module" {
  context "valid manifest" {
    It "has a valid manifest" {
      # these types of errors  might be caught by the import statement in line 1
      # but check explicitly to be sure for all cases
      Test-ModuleManifest -Path (Join-Path (Split-Path $PSCommandPath) 'PuppetBolt' 'PuppetBolt.psd1') -ErrorAction Stop
    }
  }

  context "bolt module setup" {
    BeforeEach {
      $commands = Get-Command -Module 'PuppetBolt'
    }

    it "has the correct number of exported functions" {
      # should count of pwsh functions
      @($commands).Count | Should -Be 24
    }
  }
}

Describe "test bolt command syntax" {

  context "bolt apply" {

    BeforeEach {
      $command = Get-Command -Name 'Invoke-BoltApply'
    }

    It "has primary parameter" {
      $command.Parameters['manifest'] | Should -Be $true
      $command.Parameters['manifest'].ParameterSets.Values.IsMandatory | Should -Be $true
    }

    It "has correct number of parameters" {
      ($command.Parameters.Values | Where-Object {
          $_.name -notin $common
      } | measure-object).Count | Should -Be 37
    }
  }

  context "bolt command" {
    BeforeEach {
      $command = Get-Command -Name 'Invoke-BoltCommand'
    }

    It "has primary parameter" {
      $command.Parameters['command'] | Should -Not -BeNullOrEmpty
      $command.Parameters['command'] | Should -Be $true
      $command.Parameters['command'].ParameterSets.Values.IsMandatory | Should -Be $true
    }

    It "has correct number of parameters" {
      ($command.Parameters.Values | Where-Object {
        $_.name -notin $common
      } | measure-object).Count | Should -Be 34
    }
  }

  context "boltfile" {
    BeforeEach {
      $command = Get-Command -Name 'Send-BoltFile'
    }

    It "has primary parameter" {
      $command.Parameters['source'] | Should -Not -BeNullOrEmpty
      $command.Parameters['source'] | Should -Be $true
      $command.Parameters['source'].ParameterSets.Values.IsMandatory | Should -Be $true

      $command.Parameters['destination'] | Should -Not -BeNullOrEmpty
      $command.Parameters['destination'] | Should -Be $true
      $command.Parameters['destination'].ParameterSets.Values.IsMandatory | Should -Be $true
    }

    It "has correct number of parameters" {
      ($command.Parameters.Values | Where-Object {
        $_.name -notin $common
      } | measure-object).Count | Should -Be 35
    }
  }

  context "boltinventory" {
    BeforeEach {
      $command = Get-Command -Name 'Get-BoltInventory'
    }

    It "has correct number of parameters" {
      ($command.Parameters.Values | Where-Object {
        $_.name -notin $common
      } | measure-object).Count | Should -Be 9
    }

  }

}

Describe "test all bolt command examples" {
  Context "bolt apply" {
    It "bolt apply manifest.pp -t target" {
      $result = Invoke-BoltApply -manifest 'manifest.pp' -target 'target'
      $result | Should -Be "bolt apply manifest.pp --targets target"
    }
    It "bolt apply -e `"file { '/etc/puppetlabs': ensure => present }`" -t target" {
      $result = Invoke-BoltApply -execute "file { '/etc/puppetlabs': ensure => present }" -targets 'target'
      $result | Should -Be "bolt apply --execute 'file { '/etc/puppetlabs': ensure => present }' --targets target"
    }
  }

  Context "bolt command" {
    It "bolt command run 'uptime' -t target1,target2" {
      $result = Invoke-BoltCommand -command 'uptime' -target 'target1,target2'
      $result | Should -Be "bolt command run uptime --targets target1,target2"
    }
    It "bolt command run complicated quoting" {
      $result = Invoke-BoltCommand -Command "Get-WMIObject Win32_Service -Filter \""Name like '%mon'\""" -Targets 'target1,target2'
      $result | Should -Be 'bolt command run Get-WMIObject Win32_Service -Filter \"Name like ''%mon''\" --targets target1,target2'
    }
  }

  Context "bolt file upload" {
    It "bolt file upload /tmp/source /etc/profile.d/login.sh -t target1" {
      $result = Send-BoltFile '/tmp/source' '/etc/profile.d/login.sh' -target 'target1'
      Write-Warning "this works but order is not same"
      # $result | Should -Be "bolt file upload /tmp/source /etc/profile.d/login.sh -t target1 warn on purpose"
      $result | Should -Be "bolt file upload --targets target1 /tmp/source /etc/profile.d/login.sh"
    }
  }

  Context "bolt file download" {
    It "bolt file download /etc/profile.d/login.sh login_script -t target1" {
      $result = Receive-BoltFile '/etc/profile.d/login.sh' 'login_script' -target 'target1'
      Write-Warning "this works but order is not same"
      $result | Should -Be "bolt file download --targets target1 /etc/profile.d/login.sh login_script"
    }
  }

  Context "bolt group" {
    It "bolt group show" {
      $result = Get-BoltGroup
      # this works but is not 100%
      $result | Should -Be "bolt group show"
    }
  }

  Context "bolt inventory" {
    It "bolt inventory show" {
      $result = Get-BoltInventory
      Write-Warning "this works but is not 100%"
      $result | Should -Be "bolt inventory show"
    }
  }

  Context "bolt plan" {
    It "bolt plan show" {
      $result = Get-BoltPlan
      $result | Should -Be "bolt plan show"
    }
    It "bolt plan show aggregate::count" {
      $result = Get-BoltPlan -name 'aggregate::count'
      $result | Should -Be "bolt plan show aggregate::count"
    }
    It "bolt plan convert path/to/plan/myplan.yaml" {
      $result = Convert-BoltPlan -name 'path/to/plan/myplan.yaml'
      $result | Should -Be "bolt plan convert path/to/plan/myplan.yaml"
    }
    It "bolt plan run canary --targets target1,target2 command=hostname" {
      Write-Warning 'requires params to not be positionl...is that a problem'
      $result = Invoke-BoltPlan -name 'canary' -targets 'target1,target2' -params 'command=hostname'
      $result | Should -Be "bolt plan run canary --targets target1,target2 --params 'command=hostname'"
    }
    It "bolt plan run canary --targets target1,target2 command=hostname" {
      Write-Warning 'requires params to not be positionl...is that a problem'
      $result = Invoke-BoltPlan -name 'canary' -targets 'target1,target2' -params @{ 'command' = 'hostname' }
      # Linux platforms and windows platforms will format the param strings differently:
      # on windows the format is wrapped in single qoutes with no backslash, while linux
      # variants require backslash escaped quotes and no single quote wrapping
      if ($IsWindows) {
        $result | Should -Be "bolt plan run canary --targets target1,target2 --params '{`"command`":`"hostname`"}'"
      } else {
        $result | Should -Be "bolt plan run canary --targets target1,target2 --params {\`"command\`":\`"hostname\`"}"
      }
    }
    It "bolt plan new myproject::myplan" {
      $result = New-BoltPlan -name 'myproject::myplan'
      $result | Should -Be "bolt plan new myproject::myplan"
    }
  }

  Context "bolt plan" {
    It "bolt plan show" {
      $result = Get-BoltPlan
      $result | Should -Be "bolt plan show"
    }
  }

  Context "bolt project" {
    It "bolt project migrate" {
      $result = Update-BoltProject
      $result | Should -Be "bolt project migrate"
    }
    It "bolt project init" {
      $result = New-BoltProject
      $result | Should -Be "bolt project init"
    }
    It "bolt project init myproject" {
      $result = New-BoltProject -name 'myproject'
      $result | Should -Be "bolt project init myproject"
    }
    It "bolt project init --modules puppetlabs-apt,puppetlabs-ntp" {
      $result = New-BoltProject -modules 'puppetlabs-apt,puppetlabs-ntp'
      $result | Should -Be "bolt project init --modules puppetlabs-apt,puppetlabs-ntp"
    }
  }

  Context "bolt module" {
    It "bolt module add" {
      $result = Add-BoltModule -M puppetlabs-yaml
      $result | Should -Be "bolt module add puppetlabs-yaml"
    }
    It "bolt module generate-types" {
      $result = Register-BoltModuleTypes
      $result | Should -Be 'bolt module generate-types'
    }
    It "bolt module install" {
      $result = Install-BoltModule
      $result | Should -Be 'bolt module install'
    }
    It "bolt module show" {
      $result = Get-BoltModule
      $result | Should -Be 'bolt module show'
    }
  }


  Context "bolt script" {
    It "bolt script run myscript.sh 'echo hello' --targets target1,target2" {
      $result = Invoke-BoltScript -script 'myscript.sh' -arguments 'echo hello' -targets 'target1,target2'
      Write-Warning "Verify this"
      # This does work without quotes being explicitly added here
      $result | Should -Be "bolt script run myscript.sh echo hello --targets target1,target2"
    }
  }

  Context "bolt secret" {
    It "bolt secret decrypt ciphertext" {
      $results = Unprotect-BoltSecret -Text 'ciphertext'
      $results | Should -Be "bolt secret decrypt ciphertext"
    }
    It "bolt secret encrypt plaintext" {
      $results = Protect-BoltSecret -Text 'plaintext'
      $results | Should -Be "bolt secret encrypt plaintext"
    }
  }

  Context "bolt task" {
    It "bolt task run package --targets target1,target2 action=status name=bash" {
      $results = Invoke-BoltTask -name 'package' -targets 'target1,target2' action=status name=bash
      $results | Should -Be "bolt task run package --targets target1,target2 action=status name=bash"

      $results = Invoke-BoltTask -name 'package' -targets 'target1,target2' -params '{"name":"bash","action":"status"}'
      $results | Should -Be "bolt task run package --targets target1,target2 --params '{`"name`":`"bash`",`"action`":`"status`"}'"

      $results = Invoke-BoltTask -name 'package' -targets 'target1,target2' -params @{ 'name' = 'bash'; 'action' = 'status' }
      # Linux platforms and windows platforms will format the param strings differently:
      # on windows the format is wrapped in single qoutes with no backslash, while linux
      # variants require backslash escaped quotes and no single quote wrapping
      if ($IsWindows) {
        # We don't care about the order of JSON keys, and they might become out
        # of order due to ConvertToJson
        $results | Should -BeIn @("bolt task run package --targets target1,target2 --params '{`"name`":`"bash`",`"action`":`"status`"}'",
          "bolt task run package --targets target1,target2 --params '{`"action`":`"status`",`"name`":`"bash`"}'")
      } else {
        # We don't care about the order of JSON keys, and they might become out
        # of order due to ConvertToJson
        $results | Should -BeIn @("bolt task run package --targets target1,target2 --params {\`"name\`":\`"bash\`",\`"action\`":\`"status\`"}",
          "bolt task run package --targets target1,target2 --params {\`"action\`":\`"status\`",\`"name\`":\`"bash\`"}")
      }
    }
    It "bolt task show" {
      $results = Get-BoltTask
      $results | Should -Be "bolt task show"
    }
    It "bolt task show canary" {
      $results = Get-BoltTask -name 'canary'
      $results | Should -Be "bolt task show canary"
    }
  }

  Context "bolt lookup" {
    It "bolt lookup key --targets target1,target2" {
      $results = Invoke-BoltLookup -key 'key' -targets 'target1,target2'
      $results | Should -Be "bolt lookup key --targets target1,target2"
    }
  }
}
