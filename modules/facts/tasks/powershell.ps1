#!powershell.exe

# Delegate to facter if available
if (Get-Command facter -ErrorAction SilentlyContinue) {
    facter --json
} else {
    if ([System.Environment]::OSVersion.Platform -gt 2) { # [System.PlatformID]::Win32NT
@'
{
  "_error": {
    "kind": "minfact/noname",
    "msg": "Could not determine OS name"
  }
}
'@
    } else {
        $release = [System.Environment]::OSVersion.Version.ToString() -replace '\.[^.]*\z'
        $version = $release -replace '\.[^.]*\z'

        # This fails for regular users unless explicitly enabled
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $consumerrel = $os.ProductType -eq '1'

        if ($version -eq '10.0') {
            $release = if ($consumerrel) { '10' } else { '2016' }
        } elseif ($version -eq '6.3') {
            $release = if ($consumerrel) { '8.1' } else { '2012 R2' }
        } elseif ($version -eq '6.2') {
            $release = if ($consumerrel) { '8' } else { '2012' }
        } elseif ($version -eq '6.1') {
            $release = if ($consumerrel) { '7' } else { '2008 R2' }
        } elseif ($version -eq '6.0') {
            $release = if ($consumerrel) { 'Vista' } else { '2008' }
        } elseif ($version -eq '5.2') {
            $release = if ($consumerrel) { 'XP' } else {
                if ($os.OtherTypeDescription -eq 'R2') { '2003 R2' } else { '2003' }
            }
        }

@"
{
  "os": {
    "name": "windows",
    "release": {
      "full": "$release",
      "major": "$release"
    },
    "family": "windows"
  }
}
"@
    }
}
