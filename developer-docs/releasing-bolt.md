# Releasing Bolt 

Hello, fearless reader! This document details the release process for Bolt packages and the PuppetBolt
PowerShell module.

## Bolt packages

1. Generate the changelog using the changelog rake task, where `VERSION` is the next tagged version of Bolt.

   ```bash
   $ rake 'changelog[VERSION]'
   ```
   
   Open a PR against `puppetlabs/bolt` and merge the changes into `main`.

   > **Note:** To use the rake task you must be a member of the `puppetlabs` organization and set the environment
     variable `GITHUB_TOKEN` with a [personal access token](https://github.com/settings/tokens) that has
     `admin:read:org` permissions.

1. Ensure that the [Bolt pipelines](https://jenkins-master-prod-1.delivery.puppetlabs.net/view/bolt/) are green.

1. Build and stage packages with the 
   [init_bolt-release job](https://jenkins-master-prod-1.delivery.puppetlabs.net/view/bolt/job/platform_bolt-vanagon_bolt-release-init_bolt-release/).
   Click on _Build with Parameters_ and set `NEW_TAG` to the next tagged version of Bolt. Click _Build_.

1. Once packages are staged and you are ready to push them to public repositories, run the
   [release job](https://jenkins-master-prod-1.delivery.puppetlabs.net/view/bolt/job/platform_ship-bolt_stage-foss-artifacts-all-repos/).
   Click on _Build with Parameters_ and set `REFS` to the next tagged version of Bolt. Click _Build_. 
   
   Once the release pipeline is complete it will kick off additional jobs, including the
   [puppet-bolt docker job](https://jenkins-master-prod-1.delivery.puppetlabs.net/view/bolt/job/platform_ship-bolt_build_and_push_bolt_docker_image/)
   and [docs publishing job](https://jenkins-master-prod-1.delivery.puppetlabs.net/view/bolt/job/platform_ship-bolt_publish_docs/).
   If these jobs are not kicked off automatically, they can be triggered manually without affecting the release.

1. After packages are made public, update the [Homebrew tap](https://github.com/puppetlabs/homebrew-puppet) with the
   new version of Bolt. Checkout a new release branch and run the following rake task:

   ```bash
   $ rake 'brew:cask[puppet-bolt]'
   ```

   Open a PR against `puppetlabs/homebrew-puppet`, wait for the Travis CI tests to pass, and then merge to
   `master`

1. Once packages are public, send an email to the `internal-puppet-products-update` group with the release
   notes and announce the new version in the `#bolt` channel on the community Slack.

## PuppetBolt PowerShell module

Releasing a new version of the PuppetBolt PowerShell module is currently a manual process.

### Prerequisites

Before getting started, you should have the following installed on your system:

- [.Net SDK](https://dotnet.microsoft.com/download)
- [PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.1)

### Releasing

After the Bolt repository has been tagged for a new release, you can release a new version
of the PuppetBolt module:

1. Build the PowerShell module:

   ```powershell
   > bundle exec rake pwsh:generate_module
   ```

1. Confirm that the contents of `./pwsh_module/PuppetBolt` were updated and that the
   version listed in `./pwsh_module/PuppetBolt/PuppetBolt.psd1` matches the new
   Bolt version.

1. Publish the module to PowerShell Gallery:

   ```powershell
   > Publish-Module -Path ./pwsh_module/PuppetBolt -NuGetApiKey <API KEY>
   ```

   The API key can be found in the _PowerShell Gallery_ vault in 1Password. If you do not
   have access to this vault, file a ticket with the help desk to be added to it.
