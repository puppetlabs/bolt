$InformationPreference = 'Continue'
$ErrorActionPreference = 'Stop'

$ReleaseID = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ReleaseId
if ($ReleaseID -eq "1607") {
  # Default cached images on GitHub Actions Windows 2016 workers
  # https://help.github.com/en/actions/automating-your-workflow-with-github-actions/software-installed-on-github-hosted-runners#docker-images
  $ENV:WINDOWS_TAG = "ltsc2016"
} else {
  # Default cached images on GitHub Actions Windows 2019 workers
  # https://help.github.com/en/actions/automating-your-workflow-with-github-actions/software-installed-on-github-hosted-runners#docker-images-1
  $ENV:WINDOWS_TAG = "ltsc2019"
}
Write-Output "Will use windows image tag $($ENV:WINDOWS_TAG)"

# Remove the current NAT network and pre-create the network for docker-compose
Write-Output "Removing current NAT network..."
Remove-NetNat -Confirm:$false

# Create the new network
Write-Output "Creating spec_default docker network..."
& cmd /c --% docker network create spec_default --driver nat 2>&1

# Create the needed containers for testing
Write-Output "Creating windows container/s..."
& cmd /c --% docker-compose --file spec/docker-compose-windows.yml --verbose --no-ansi up --detach --build 2>&1
