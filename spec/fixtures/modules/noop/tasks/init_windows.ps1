[CmdletBinding()]
Param(
  [Bool]$_noop = $False
)

if($_noop -eq 'true') {
  Write-Output '{"noop":true}'
} else {
  Write-Output '{"noop":false}'
}
