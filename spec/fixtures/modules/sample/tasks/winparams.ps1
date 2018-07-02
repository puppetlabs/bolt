[CmdletBinding()]
param(
  [Parameter(Mandatory = $True)]
  [string]
  $Message
)

Write-Output "Message: $Message"