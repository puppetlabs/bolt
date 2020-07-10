# Adding gem dependencies

When new gem dependencies are added to Bolt, it's important to add them to both the bolt-runtime and pe-bolt-server-runtime. You can add the gem dependencies by following these steps:

1. Open a PR in the [puppet-runtime repo](https://github.com/puppetlabs/puppet-runtime) with the following changes:

    * Add each gem to the [config components directory](https://github.com/puppetlabs/puppet-runtime/tree/master/configs/components). The file for a gem component should be named `rubygem-<GEM_NAME>.rb`.

        ```ruby
        component "rubygem-<GEM_NAME>" do |pkg, settings, platform|
          pkg.version "<GEM_VERSION>"
          pkg.md5sum "<GEM_MD5SUM>"

          instance_eval File.read('configs/components/_base-rubygem.rb')
        end
        ```

    * Add the components to the [bolt-runtime](https://github.com/puppetlabs/puppet-runtime/blob/master/configs/projects/bolt-runtime.rb) and [_shared-pe-bolt-server](https://github.com/puppetlabs/puppet-runtime/blob/master/configs/projects/_shared-pe-bolt-server.rb).

        ```ruby
        proj.component 'rubygem-<GEM_NAME>'
        ```

    * Add the components to the artifactory mirror. This can be done easily with Kerminator by posting in `#release-new-new`.

        ```
        !mirrorsource https://rubygems.org/downloads/<GEM_NAME>-<GEM_VERSION>.gem
        ```
    
1. Once the PR has been merged, wait for the [bolt-runtime pipeline](https://jenkins-platform.delivery.puppetlabs.net/view/puppet-runtime/view/bolt-runtime/) to finish running and promote bolt-vanagon. This is an ([example promotion commit](https://github.com/puppetlabs/bolt-vanagon/commit/850774cb232a76667350dfe1a13644853b4eee8c)).

1. Open a PR in the [Bolt repo](https://github.com/puppetlabs/bolt) with the following changes:

    * Add each gem to [`bolt.gemspec`](https://github.com/puppetlabs/bolt/blob/main/bolt.gemspec).

        ```ruby
        spec.add_dependency "<GEM_NAME>", "<GEM_VERSION>"
        ```
