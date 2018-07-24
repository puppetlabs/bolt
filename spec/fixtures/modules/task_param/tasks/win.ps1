[CmdletBinding()]
param(
  [Parameter(Mandatory = $False)]
  [String]
  $_task
)

Write-Output "Running task $_task"
