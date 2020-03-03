$InformationPreference = 'Continue'
$ErrorActionPreference = 'Stop'

# Ensure Puppet Ruby 5 / 6 takes precedence over system Ruby
# https://github.com/puppetlabs/puppet-specifications/blob/master/file_paths.md
$path = @(
    "${ENV:ProgramFiles}\Puppet Labs\Puppet\sys\ruby\bin",
    "${ENV:ProgramFiles}\Puppet Labs\Puppet\puppet\bin",
    $ENV:Path
    ) -join ';'

[System.Environment]::SetEnvironmentVariable('Path', $path, [System.EnvironmentVariableTarget]::Machine)
