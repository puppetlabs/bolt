function bolt {
  $fso = New-Object -ComObject Scripting.FileSystemObject

  $script:BOLT_BASEDIR = (Get-ItemProperty -Path "HKLM:\Software\Puppet Labs\Bolt").RememberedInstallDir
  # Windows API GetShortPathName requires inline C#, so use COM instead
  $script:BOLT_BASEDIR = $fso.GetFolder($script:BOLT_BASEDIR).ShortPath
  $script:RUBY_DIR = $script:BOLT_BASEDIR

  if (!$env:SSL_CERT_FILE) {
    $env:SSL_CERT_FILE = "$($script:BOLT_BASEDIR)\ssl\cert.pem"
  }
  if (!$env:SSL_CERT_DIR) {
    $env:SSL_CERT_DIR = "$($script:BOLT_BASEDIR)\ssl\certs"
  }

  &$script:RUBY_DIR\bin\ruby -S -- $script:RUBY_DIR\bin\bolt ($args -replace '"', '"""')
}

function Invoke-BoltCommandline {
  [CmdletBinding()]
  param($params)
  $fso = New-Object -ComObject Scripting.FileSystemObject

  $script:BOLT_BASEDIR = (Get-ItemProperty -Path "HKLM:\Software\Puppet Labs\Bolt").RememberedInstallDir
  # Windows API GetShortPathName requires inline C#, so use COM instead
  $script:BOLT_BASEDIR = $fso.GetFolder($script:BOLT_BASEDIR).ShortPath
  $script:RUBY_DIR = $script:BOLT_BASEDIR

  if (!$env:SSL_CERT_FILE) {
    $env:SSL_CERT_FILE = "$($script:BOLT_BASEDIR)\ssl\cert.pem"
  }
  if (!$env:SSL_CERT_DIR) {
    $env:SSL_CERT_DIR = "$($script:BOLT_BASEDIR)\ssl\certs"
  }

  $processArgs = @('-S', '--', "$script:RUBY_DIR\bin\bolt") + $params

  Write-Verbose "Executing $($script:RUBY_DIR)\bin\ruby $($processArgs -join ' ')"

  &$script:RUBY_DIR\bin\ruby $processArgs
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
