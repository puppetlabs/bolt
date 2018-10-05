---
author: Kate Lopresti <kate.lopresti@puppet.com\>
---

# Applying manifest blocks

Within a plan, you can use Bolt to apply blocks of Puppet code \(manifest blocks\) to remote nodes. 

Similar to the `puppet apply` command, which applies a standalone Puppet manifest to a local system, the Bolt `apply` command leverages manifest blocks to pass code to remote nodes from the command line. You can create manifest blocks that use existing content from the Forge, or mix declarative resource configuration via manifest blocks with procedural orchestration and action in a plan. Most features of the Puppet language are available in a manifest block: classes, custom resource types, and functions. Exceptions are noted.

**Tip:** If you installed Bolt as a Ruby Gem, make sure you have installed the core modules required to use the `puppet apply` command. These modules are listed in the [Bolt GitHub repository](https://github.com/puppetlabs/bolt/blob/master/Puppetfile)and you can install them using a Puppetfile.

**Related information**  


[Set up Bolt to download and install modules](installing_tasks_from_the_forge.md#)

[Puppetfile example](https://github.com/puppetlabs/bolt/blob/master/Puppetfile)

[Puppet Forge](https://forge.puppet.com/)

## Using Hiera data in a manifest block

Use Hiera to separate configuration from context-specific data, where context may be fact-based or the name of a target.

**Note:** Only Hiera version 5 is supported in Bolt.

Hiera is a built-in key-value configuration data lookup system, used for separating data from Puppet code. You use Hiera data to implicitly override default class parameters. You can also explicitly lookup data from Hiera via lookup, for example:

```
plan do_thing() {
  apply('localhost') {
    notice("Some data in Hiera: ${lookup('mydata')}")
  }
}
```

Manifest block compilation can access Hiera data that you add to your Bolt config. The default location for Hiera config is `$BOLTDIR/hiera.yaml`; you can change this with the `hiera-config`key in a Bolt config file.

Following the Hiera 5 convention, the default data dir is relative to `hiera.yaml` at `$BOLTDIR/data`. For config file examples, see [Configuring Hiera](https://puppet.com/docs/puppet/6.0/hiera_config_yaml_5.html).

If a custom data provider is used \(such as `hiera-eyaml`, which allows you to encrypt your data\) the gem dependencies must be available to Bolt. If using `puppet-bolt` packages and installing `hiera-eyaml`

-   on Windows, run `"C:/Program Files/Puppet Labs/Bolt/bin/gem.bat" install hiera-eyaml`

-   on other platforms, run `/opt/puppetlabs/bolt/bin/gem install hiera-eyaml`


## Available plan functions

In addition to the standard Puppet functions available to a catalog, such as `lookup`, you can use the following Bolt functions in a manifest block.

-    [puppetdb\_query](plan_functions.md#) 

-    [puppetdb\_facts](plan_functions.md#) 

-    [get\_targets](plan_functions.md#) 

-    [facts](plan_functions.md#) 

-    [vars](plan_functions.md#) 


## Manifest block limitations

Review what functionality is not available for use in manifest block.

Exported resources are not supported in manifest blocks. You should pass exported resources directly instead of exporting and collecting them from PuppetDB. If you need to interact with resources managed during a normal run, use [puppetdb\_query](plan_functions.md#).

In addition, there are some top level variables that exist in normal catalog compilation that are not included during manifest block compilation:

-   `$server_facts`

-   master variables like `$servername`

-   $`environment`


If needed you can set these from a target's `vars`, but they don't have obvious defaults in Bolt.

## Create a sample manifest for nginx on Linux

Create a manifest to set up a web server with nginx and run it as a plan.

Save this module in the Bolt default Boltdir \(`~/.puppetlabs/bolt`\).

1.  Go to `~/.puppetlabs/bolt/modules`
2.   Create a module. 
    -   If you use the Puppet Development Kit: `pdk new module profiles` and add a `plans` directory 
    -   Otherwise create `~/.puppetlabs/bolt/modules/profiles/plans`
3.  Add the following code to the manifest: `profiles/plans/nginx_install.pp` 

    ```
    plan profiles::nginx_install(
         TargetSpec $nodes,
         String $site_content = 'hello!',
       ) {
    
         # Install the puppet-agent package if Puppet is not detected.
         # Copy over custom facts from the Bolt modulepath.
         # Run the `facter` command line tool to gather node information.
         $nodes.apply_prep
    
         # Compile the manifest block into a catalog
         apply($nodes) {
           if($facts['os']['family'] == 'redhat') {
             package { 'epel-release':
               ensure => present,
               before => Package['nginx'],
             }
             $html_dir = '/usr/share/nginx/html'
           } else {
             $html_dir = '/var/www/html'
           }
    
           package {'nginx':
             ensure => present,
           }
    
           file {"${html_dir}/index.html":
             content => $site_content,
             ensure  => file,
           }
    
           service {'nginx':
             ensure  => 'running',
             enable  => 'true',
             require => Package['nginx']
           }
         }
       }
    ```

4.  Run the plan on a target node: `bolt plan run profiles::nginx_install --nodes <NODE NAME>`.
5.  From a web browser, navigate to `<NODE NAME>`. 

    The page displays the text **hello!**


**Tip:** For more complex web server deployments, consider adding the [puppet-nginx](https://github.com/voxpupuli/puppet-nginx) module.

**Related information**  


[NGINX](https://www.nginx.com/resources/glossary/nginx/)

## Create a sample manifest for IIS on Windows

Create a manifest to set up a web server with IIS and run it as a plan.

Save this module in the Bolt default Boltdir \(`~/.puppetlabs/bolt`\).

1.  Go to `~/.puppetlabs/bolt/modules`
2.   Create a module. 
    -   If you use the Puppet Development Kit: `pdk new module profiles` and add a `plans` directory 
    -   Otherwise create `~/.puppetlabs/bolt/modules/profiles/plans`
3.  Install the IIS dependencies.
    1.  Add the following code to `~/.puppetlabs/bolt/Puppetfile` 

        ```
        forge 'http://forge.puppetlabs.com'
        mod 'puppetlabs-iis', '4.3.2'
        mod 'profiles', local: true
        ```

    2.  Run `bolt puppetfile install`
4.  Add the following code to the manifest: `profiles/plans/iis_install.pp` 

    ```
    plan profiles::iis_install(
         TargetSpec $nodes,
         String $site_content = 'hello!',
       ) {
    
         # Install the puppet-agent package if Puppet is not detected. 
         # Copy over custom facts from the Bolt modulepath.
         # Run the `facter` command line tool to gather node information.
         $nodes.apply_prep
    
         # Compile the manifest block into a catalog
         return apply($nodes, '_catch_errors' => true) {
           $iis_features = ['Web-WebServer','Web-Scripting-Tools']
    
           iis_feature { $iis_features:
             ensure => 'present',
           }
    
           # Delete the default website to prevent a port binding conflict.
           iis_site {'Default Web Site':
             ensure  => absent,
             require => Iis_feature['Web-WebServer'],
           }
    
           iis_site { 'minimal':
             ensure          => 'started',
             physicalpath    => 'c:\\inetpub\\minimal',
             applicationpool => 'DefaultAppPool',
             require         => [
               File['minimal'],
               Iis_site['Default Web Site']
             ],
           }
    
           file { 'minimal':
             ensure => 'directory',
             path   => 'c:\\inetpub\\minimal',
           }
    
           file { 'content':
             ensure  => 'file',
             path    => 'c:\\inetpub\\minimal\\index.html',
             content => $site_content,
           }
         }
       }
    ```

5.  Run the plan on a target node: `bolt plan run profiles::iis_install --nodes <NODE NAME> --transport winrm`
6.  From a web browser, navigate to `<NODE NAME>`. 

    The page displays the text **hello!**


**Related information**  


[IIS](https://www.iis.net)

