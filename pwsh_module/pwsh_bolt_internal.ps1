function Invoke-BoltCommandline {
  [CmdletBinding()]
  param($params)

  Write-Verbose "Executing bolt $($params -join ' ')"

  bolt $params
}

function Get-BoltCommandline {
  param($parameterHash, $mapping)

  $common = @(
    'ErrorAction', 'ErrorVariable', 'InformationAction',
    'InformationVariable', 'OutBuffer', 'OutVariable', 'PipelineVariable',
    'WarningAction', 'WarningVariable', 'Confirm', 'Whatif'
  )

  $params = @()
  foreach ($kvp in $parameterHash.GetEnumerator()) {
    if ($kvp.Key -in $common) {
      Write-Verbose "Skipping common parameter: $($kvp.Key)"
      continue
    }
    else {
      Write-Verbose "Examining $($kvp.Key)"
    }
    $pwshParameter = $kvp.Key
    $pwshValue = $kvp.Value
    $rubyParameter = $mapping[$pwshParameter]

    if ($pwshValue -is [System.Management.Automation.SwitchParameter]) {
      Write-Verbose "Parsing $($kvp.key) as switch parameter"
      if ($pwshValue -eq $true) {
        $params += "--$($rubyParameter)"
      }
      else {
        $params += "--no-$($rubyParameter)"
      }
    }
    elseif ($pwshValue -is [System.Collections.Hashtable]) {
      Write-Verbose "Parsing $($kvp.key) as hashtable parameter"
      $v = ConvertTo-Json -InputObject $pwshValue -Compress
      $params += "--$($rubyParameter)"
      $params += "'$($v)'"
    }
    elseif ($pwshValue.GetType().Name -eq 'List`1') {
      Write-Verbose "Parsing $($kvp.key) as array parameter"
      $pwshValue | Foreach-Object {
        $params += "$($_)"
      }
    }
    else {
      Write-Verbose "Parsing $($kvp.key) as default"
      if ($rubyParameter) {
        $params += "--$($rubyParameter)"
      }

      $parsedValue = switch ($pwshParameter) {
        'params' { "'$($pwshValue)'" }
        'execute' { "'$($pwshValue)'" }
        Default { $pwshValue }
      }

      $params += $parsedValue
    }
  }

  Write-Output $params
}

function Get-BoltVersion{
  [CmdletBinding()]
  param()

  $module = Get-Module -Name PuppetBolt
  Write-Output [string]($module.Version)
}
