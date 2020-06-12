Import-Module -Name (Join-Path (Split-Path $PSCommandPath) 'pwsh_bolt.psm1') -Force
BeforeAll {

  Mock -ModuleName 'pwsh_bolt' -Verifiable -CommandName Invoke-BoltCommandLine -MockWith {
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
      } | measure-object).Count | Should -Be 33
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
      } | measure-object).Count | Should -Be 10
    }

  }

}

Describe "test all bolt command examples" {
  Context "bolt apply" {
    It "bolt apply manifest.pp -t target" {
      $result = Invoke-BoltApply -manifest 'manifest.pp' -target 'target'
      $result | Should -Be "bolt apply 'manifest.pp' --targets 'target'"
    }
    It "bolt apply -e `"file { '/etc/puppetlabs': ensure => present }`" -t target" {
      $result = Invoke-BoltApply -execute "file { '/etc/puppetlabs': ensure => present }" -targets 'target'
      $result | Should -Be "bolt apply --execute 'file { '/etc/puppetlabs': ensure => present }' --targets 'target'"
    }
  }

  Context "bolt command" {
    It "bolt command run 'uptime' -t target1,target2" {
      $result = Invoke-BoltCommand -command 'uptime' -target 'target1,target2'
      $result | Should -Be "bolt command run 'uptime' --targets 'target1,target2'"
    }
  }

  Context "bolt file upload" {
    It "bolt file upload /tmp/source /etc/profile.d/login.sh -t target1" {
      $result = Send-BoltFile '/tmp/source' '/etc/profile.d/login.sh' -target 'target1'
      Write-Warning "this works but order is not same"
      # $result | Should -Be "bolt file upload /tmp/source /etc/profile.d/login.sh -t target1 warn on purpose"
      $result | Should -Be "bolt file upload --targets 'target1' '/tmp/source' '/etc/profile.d/login.sh'"
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
      $result = Get-BoltPlan -plan 'aggregate::count'
      $result | Should -Be "bolt plan show 'aggregate::count'"
    }
    It "bolt plan convert path/to/plan/myplan.yaml" {
      $result = Convert-BoltPlan -plan 'path/to/plan/myplan.yaml'
      $result | Should -Be "bolt plan convert 'path/to/plan/myplan.yaml'"
    }
    It "bolt plan run canary --targets target1,target2 command=hostname" {
      Write-Warning 'requires params to not be positionl...is that a problem'
      $result = Invoke-BoltPlan -plan 'canary' -targets 'target1,target2' -params 'command=hostname'
      $result | Should -Be "bolt plan run 'canary' --targets 'target1,target2' --params 'command=hostname'"
    }
    It "bolt plan run canary --targets target1,target2 command=hostname" {
      Write-Warning 'requires params to not be positionl...is that a problem'
      $result = Invoke-BoltPlan -plan 'canary' -targets 'target1,target2' -params @{ 'command' = 'hostname' }
      $result | Should -Be "bolt plan run 'canary' --targets 'target1,target2' --params '{`"command`":`"hostname`"}'"
    }
  }

  Context "bolt plan" {
    It "bolt plan show" {
      $result = Get-BoltPlan
      $result | Should -Be "bolt plan show"
    }
    It "bolt project init" {
      $result = New-BoltProject
      $result | Should -Be "bolt project init"
    }
    It "bolt project init ~/path/to/project" {
      $result = New-BoltProject -Directory '~/path/to/project'
      $result | Should -Be "bolt project init '~/path/to/project'"
    }
    It "bolt project init --modules puppetlabs-apt,puppetlabs-ntp" {
      $result = New-BoltProject -modules 'puppetlabs-apt,puppetlabs-ntp'
      $result | Should -Be "bolt project init --modules 'puppetlabs-apt,puppetlabs-ntp'"
    }
  }

  Context "bolt project" {
    It "bolt project migrate" {
      $result = Update-BoltProject
      $result | Should -Be "bolt project migrate"
    }
    It "bolt project migrate 'foo'" {
      $result = Update-BoltProject -directory 'foo'
      $result | Should -Be "bolt project migrate 'foo'"
    }
  }

  Context "bolt puppetfile" {
    It "bolt puppetfile generate-types" {
      $result = Register-BoltPuppetfileTypes
      $result | Should -Be 'bolt puppetfile generate-types'
    }
    It "bolt puppetfile install" {
      $result = Install-BoltPuppetfile
      $result | Should -Be 'bolt puppetfile install'
    }
    It "bolt puppetfile show-modules" {
      $result = Get-BoltPuppetfileModules
      $result | Should -Be 'bolt puppetfile show-modules'
    }
  }

  Context "bolt script" {
    It "bolt script run myscript.sh 'echo hello' --targets target1,target2" {
      $result = Invoke-BoltScript -script 'myscript.sh' -arguments 'echo hello' -targets 'target1,target2'
      Write-Warning "Verify this"
      $result | Should -Be "bolt script run 'myscript.sh' 'echo hello' --targets 'target1,target2'"
    }
  }

  Context "bolt secret" {
    It "bolt secret decrypt ciphertext" {
      $results = Unprotect-BoltSecret -text 'ciphertext'
      $results | Should -Be "bolt secret decrypt 'ciphertext'"
    }
    It "bolt secret encrypt plaintext" {
      $results = Protect-BoltSecret -text 'plaintext'
      $results | Should -Be "bolt secret encrypt 'plaintext'"
    }
  }

  Context "bolt task" {
    It "bolt task run package --targets target1,target2 action=status name=bash" {
      $results = Invoke-BoltTask -task 'package' -targets 'target1,target2' -params 'action=status name=bash'
      Write-Warning "Come back to this"
      $results | Should -Be "bolt task run 'package' --targets 'target1,target2' --params 'action=status name=bash'"

      # $results = Invoke-BoltTask -task 'package' -targets 'target1,target2' -params @{ 'action' = 'status'; 'name' = 'bash' }
      # Write-Warning "Come back to this"
      # $results | Should -Be "bolt task run 'package' --targets 'target1,target2' --params 'action=status name=bash'"
    }
    It "bolt task show" {
      $results = Get-BoltTask
      $results | Should -Be "bolt task show"
    }
    It "bolt task show canary" {
      $results = Get-BoltTask -task 'canary'
      $results | Should -Be "bolt task show 'canary'"
    }
  }
}
