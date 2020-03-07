# Releasing Bolt 

Hello, fearless reader! This document details the release process for Bolt. Our current release cadence is weekly for both the bolt gem and bolt system package, usually on Mondays. Here's how we do it: 

1. Generate the changelog using the rake task `rake 'changelog[VERSION]'`, where `VERSION` is the new tag, and merge the changes into `master`.
2. Build and stage bolt packages with the [init_bolt-release job](https://jenkins-master-prod-1.delivery.puppetlabs.net/view/bolt/job/platform_bolt-vanagon_bolt-release-init_bolt-release/) using all defaults except the new tag for Bolt. The version specified will be the new tag in the github repo.
3. Once step 2 is done and you are ready to push the packages to public repositories, run the [release job](https://jenkins-master-prod-1.delivery.puppetlabs.net/view/bolt/job/platform_ship-bolt_stage-foss-artifacts-all-repos/) with all default parameters except the new tag. This will also kick off the [docs publishing job](https://jenkins-master-prod-1.delivery.puppetlabs.net/view/bolt/job/platform_ship-bolt_publish_docs/) which will build and publish the docs based on the new tag. Note that this job can be run against any REF as a stand-alone pipeline in the case where a change is needed outside of a tagged version. 
4. After packages are made public update the [Homebrew tap](https://github.com/puppetlabs/homebrew-puppet) with the new version of bolt. This can be accomplished by running the rake task `rake 'brew:cask[puppet-bolt]'` and opening a PR with the changes. Make sure the PR passes the Travis integration tests and merge the PR. 
5. Once packages are public, send an email to the internal-puppet-products-update group.
