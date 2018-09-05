# Applying Manifest Blocks

Within a plan, you can use Bolt to apply blocks of Puppet code (manifest blocks) to remote nodes. Similar to the `puppet apply` command, which applies a standalone Puppet manifest to a local system, the Bolt `apply` command leverages manifest blocks to pass code to remote nodes from the command line. You can create manifest blocks that use existing content from the Forge, or mix declarative resource configuration via manifest blocks with procedural orchestration and action in a plan. Most features of the Puppet language are available in a manifest block: classes, custom resource types, and functions. Exceptions are noted in [caveats](#caveats). 

**Parent topic:** [Tasks and plans](writing_tasks_and_plans.md)

**Related information**

[Writing plans](writing_plans.md)

## Create a sample manifest for nginx on Linux

Create a manifest to set up a web server with [nginx](https://nginx.org) and run it as a plan. 

Save this module in the Bolt default Boltdir (`~/.puppetlabs/bolt`).

1. Go to `~/.puppetlabs/bolt/modules`
1. Create a new module.
   * If you use PDK, run `pdk new module profiles` and add a `plans` directory 
   * Otherwise create `~/.puppetlabs/bolt/modules/profiles/plans`
1. Add the following code to the manifest `profiles/plans/nginx_install.pp`
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
1. Run the plan on a target node: `bolt plan run profiles::nginx_install --nodes <NODE NAME>`
1. From a web browser, navigate to `<NODE NAME>`. The page displays the text `hello!`

*Tip:* For more complex web server deployments, consider adding the [puppet-nginx](https://github.com/voxpupuli/puppet-nginx) module.

## Create a sample manifest for iis on Windows

Create a manifest to set up a web server with [iis](https://www.iis.net) and run it as a plan. 

1. Go to `~/.puppetlabs/bolt/modules`
1. Create a new module.
   * If you use PDK, run `pdk new module profiles` and add a `plans` directory 
   * Otherwise create `~/.puppetlabs/bolt/modules/profiles/plans`
1. Install the IIS dependencies
   * Add the following to `~/.puppetlabs/bolt/Puppetfile`  
   ```
   forge 'http://forge.puppetlabs.com'
   mod 'puppetlabs-iis', '4.3.2'
   mod 'profiles', local: true
   ```
   * run `bolt puppetfile install`
1. Add the following code to the manifest `profiles/plans/iis_install.pp`
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
1. Run the plan on a target node: `bolt plan run profiles::iis_install --nodes <NODE NAME> --transport winrm`
1. From a web browser, navigate to `<NODE NAME>`. The page displays the text `hello!`

### How manifest blocks are applied 

The `apply_prep` function sets up the remote node by installing our puppet-agent package from puppet.com using a `puppet_agent::install` task (from [the puppet_agent module](https://github.com/puppetlabs/puppetlabs-puppet_agent)) if Puppet is not detected on a target. It also copies over custom facts from Bolt's modulepath and executes `facter` on the targets.

Behind the scenes, Bolt compiles the manifest block (the section wrapped in curly braces following `apply`) into a catalog using (from highest to lowest precedence)
- `Facts` gathered from the targets or set in your inventory
- Local variables in the plan, such as `$site_content`
- `Vars` set in your inventory

It generates all the variables a `puppet apply` would include, so code can be reused between Bolt and Puppet. It then copies custom module content from Bolt's modulepath to the target and applies the catalog using Puppet.

When the catalog compiles and is executed successfully on all targets, apply returns the reports generated by applying the catalog on each node.

## Using Hiera Data in a manifest block

*Note:* Only Hiera version 5 is supported in Bolt

Hiera is a built-in key-value configuration data lookup system, used for separating data from Puppet code. It allows you to separate configuration from context-specific data, where context may be fact-based or the name of a target.

Hiera data is used implicitly to override default class parameters. You can also explicitly lookup data from Hiera via lookup, for example
```
plan do_thing() {
  apply('localhost') {
    notice("Some data in Hiera: ${lookup('mydata')}")
  }
}
```

Manifest block compilation can access Hiera data that you add to your Bolt config. The default location for Hiera config is `$BOLTDIR/hiera.yaml`; you can change this with the `hiera-config` key in a Bolt config file. 

Following the Hiera 5 convention, the default data dir is relative to `hiera.yaml` at `$BOLTDIR/data`. For config file examples, see https://puppet.com/docs/puppet/5.5/hiera_config_yaml_5.html.

If a custom data provider is used (such as `hiera-eyaml`, which allows you to encrypt your data) the gem dependencies must be available to Bolt. If using `puppet-bolt` packages and installing `hiera-eyaml`
- on Windows, run `"C:/Program Files/Puppet Labs/Bolt/bin/gem.bat" install hiera-eyaml`
- on other platforms, run `/opt/puppetlabs/bolt/bin/gem install hiera-eyaml`

## Available Plan Functions

In addition to normal Puppet functions available to a catalog, such as `lookup`, some of Bolt's functions will also work in a manifest block:
- [puppetdb_query](plan_functions.md#puppetdb_query)
- [puppetdb_facts](plan_functions.md#puppetdb_facts)
- [get_targets](plan_functions.md#get_targets)
- [facts](plan_functions.md#facts)
- [vars](plan_functions.md#vars)

## Options

The 'apply' function supports common metaparameters available to other Bolt functions:
- `_catch_errors => true` returns a `ResultSet` including failed results, rather than failing the plan.
- `_noop => true` applies the manifest block in Puppet's no-operation mode, returning a report of the changes it would make, but takes no action.
- `_run_as => <user>` applies the manifest block as the specified user (on transports that support it).

## Configuring Concurrency

Each target requires a separate catalog be compiled with its unique facts and vars. The 'apply' function compiles and applies catalogs in parallel on the Bolt host. Concurrency of catalog compilation is controlled by a  `compile-concurrency` config option that's limited to twice the number of threads your CPU can run concurrently, while catalog application uses Bolt's default thread pool controlled by the `concurrency` option.

## Caveats

Exported resources are not supported in manifest blocks. You should pass these values directly instead of exporting and collecting them from PuppetDB. If you need to interact with resources managed during a normal Puppet run, use [puppetdb_query](plan_functions.md#puppetdb_query).

In addition, there are some top level variables that exist in normal catalog compilation that are not included during manifest block compilation:
- `$server_facts`
- master variables like `$servername`
- `$environment`

If needed you can set these from a target's `vars`, but they don't have obvious defaults in Bolt.
