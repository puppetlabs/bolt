If($env:PT_fail -eq 'true') {
  exit 1
} Else {
  Write-Output "{`"tag`": `"you're it`"}"
}