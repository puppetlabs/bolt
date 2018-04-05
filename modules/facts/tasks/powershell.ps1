#!powershell.exe

# Delegate to facter if available
if (Get-Command facter -ErrorAction SilentlyContinue) {
    facter --json
}
else {
    # The number 2 in the condition below is the value of
    # the [System.PlatformID]::Win32NT constant. We don't
    # use the constant here as it doesn't work on Windows
    # Server Core.
    if ([System.Environment]::OSVersion.Platform -gt 2) {
        @'
{
  "_error": {
    "kind": "facts/noname",
    "msg": "Could not determine OS name"
  }
}
'@
    }
    else {
        $release = [System.Environment]::OSVersion.Version.ToString() -replace '\.[^.]*\z'
        $version = $release -replace '\.[^.]*\z'

        # This fails for regular users unless explicitly enabled
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $consumerrel = $os.ProductType -eq '1'

        $release = switch($version){
            '10.0'{ if ($consumerrel) { '10' } else { '2016' } }
            '6.3' { if ($consumerrel) { '8.1' } else { '2012 R2' } }
            '6.2' { if ($consumerrel) { '8' } else { '2012' } }
            '6.1' { if ($consumerrel) { '7' } else { '2008 R2' } }
            '6.0' { if ($consumerrel) { 'Vista' } else { '2008' } }
            '5.2' { 
                if ($consumerrel) { 'XP' } else {
                    if ($os.OtherTypeDescription -eq 'R2') { '2003 R2' } else { '2003' }
                }
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
