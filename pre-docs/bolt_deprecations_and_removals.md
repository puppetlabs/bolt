# Deprecations and removals

A list of the features and functions deprecated or removed from Bolt 0.x.

## Removed deprecated configuration location ~/.puppetlabs/bolt.yaml \(0.24.0\)

The default bolt.yaml location at `~/.puppetlabs/` has been removed. In Bolt 0.21.0 this configuration location was deprecated in favor of `~/.puppetlabs/bolt/bolt.yaml`. \([BOLT-749](https://tickets.puppetlabs.com/browse/BOLT-749)\)

## Function file\_upload changed to upload\_file \(0.22.0\)

The function `file_upload` has been renamed to `upload_file` to match the other verb-oriented core functions like `run_task`. `file_upload` is deprecated and will be removed in a future release. Note that the command `bolt file upload` is unchanged. \([BOLT-751](https://tickets.puppetlabs.com/browse/BOLT-751)\)

## Removed puppetlabs/apply module \(0.22.0\)

The [puppetlabs/apply](https://forge.puppet.com/puppetlabs/apply) module has been removed from the bundled modules included with Bolt. The Bolt`apply` command introduced in Bolt 0.21.6 replaces this functionality. If you need the `apply::resource` task, you must install it. \([BOLT-750](https://tickets.puppetlabs.com/browse/BOLT-750)\)

