# Releasing Bolt 

Hello, fearless reader! This document details the release process for Bolt. Our current release cadence is weekly for both the bolt gem and bolt system package, usually on Wednesdays. Here's how we do it: 

## The Day Before Release

Create jira tickets for both the Bolt team and RE team for release. We use an internal tool called [Winston](https://github.com/puppetlabs/winston) to generate these tickets. Here's how to use it: 

1. Clone [Winston](https://github.com/puppetlabs/winston) and `cd` into the directory 
1. Run `bundle install` 
1. Ask in the "release-new" hipchat room who should be the RE lead for this release 
1. Determine who should be the Bolt lead for this release, as well as Docs lead. 1. In the Winston directory run ``` bundle exec rake bolt bolt_release_tickets JIRA_USER= BOLT_LEAD= DOCS_LEAD= RE_LEAD= BOLT_VERSION=0.19.0 DATE=2018-04-12 ``` With updated version, date, and jira users. Note that the values for all of the leads and for the jira user are in the form of the jira username, which is typically lower-case `firstname.lastname`. 

## The Day Of Release 

You're ready to release! The tickets you created yesterday should detail how to release both the bolt gem and package step by step, but there are a few other things to make sure you do while releasing: 

1. Notify the RE lead that you're ready to release, and ensure that everything is ready to go on their end. 
1. Ensure that all tickets created by Winston are properly assigned, and on the Bolt kanban board. 
1. Do the tickets. 
1. Make sure that the correct version of bolt was released, and that it's published in the puppet5 repos and gem repos.