# Deploy a TIG stack with Bolt

In this guide, you'll use Bolt to configure and deploy a TIG stack. 

A TIG stack provides metrics visualization to help you monitor your
infrastructure. TIG stands for:
- [Telegraf](https://docs.influxdata.com/telegraf/v1.14/) - A plugin-driven
  server agent for collecting and reporting metrics.
- [InfluxDB](https://docs.influxdata.com/influxdb/v1.8/) - A time series
  database designed to handle time-stamped data like metrics and events.     
- [Grafana](https://grafana.com/docs/grafana/latest/getting-started/what-is-grafana/) -
  An open source visualization and analytics tool.

> **Before you begin**
>
> - Make sure you've installed Bolt version 2.10.0 or greater on your machine.
>  For instructions on how to install Bolt, see
>  [Installing Bolt](./bolt_installing.md).
> - Clone or download the [TIG stack repo](https://github.com/puppetlabs/bolt-tig-stack)
> - This guide uses virtual machines
>  to host the stack, which requires [Vagrant](https://www.vagrantup.com/docs/installation) and a hypervisor like 
>  [VirtualBox](https://www.virtualbox.org/). If you'd prefer to use your own
>  targets, you can skip the directions for provisioning targets and go straight
>  to [installing the TIG modules](#install-the-tig-modules).

To deploy your TIG stack, you'll use a Bolt plan that leverages existing Puppet
Modules. You can find all the files you need in the
[TIG stack repo](https://github.com/puppetlabs/bolt-tig-stack).

After you've cloned or downloaded the repo, you can access the TIG Bolt
project from the `tig_stack` directory. The project has the following file structure:

```shell
.
├── Puppetfile
├── Vagrantfile
├── bolt-project.yaml
├── data
│   └── common.yaml
├── hiera.yaml
├── inventory.yaml
├── manifests
│   ├── dashboard.pp
│   ├── params.pp
│   └── telegraf.pp
├── plans
│   └── init.pp
└── templates
    └── dashboards
        └── telegraf.json
```

## Provision your targets

A typical real-world environment would consist of multiple agents, but for the
purposes of this guide, you'll provision two virtual machines to use as
targets - `target0` and `target1`. The first target hosts the Garafana dashboard
and the InfluxDB database as well as a Telegraf agent. The second target hosts
only a Telegraf agent. If you'd prefer to use your own existing targets, skip
this section.

The `bolt_tig` directory contains the following `Vagrantfile`:

```shell
# -*- mode: ruby -*-
# vi: set ft=ruby :

TARGETS = 2

Vagrant.configure(TARGETS) do |config|
  config.vm.box = "centos/7"
  config.ssh.forward_agent = true

  TARGETS.times do |i|
    config.vm.define "target#{i}" do |target|
      target.vm.hostname = "target#{i}"
      target.vm.network :private_network, ip: "10.1.0.#{100 + i}"
    end
  end
end
```

To provision your targets:
1. Spin up your virtual machines with Vagrant:
   
   ```shell
   vagant up
   ```  
2. Generate the SSH configuration for both targets. Bolt will automatically
   detect the configuration.

    ```shell
    mkdir ~/.ssh
    vagrant ssh-config | sed /StrictHostKeyChecking/d | sed /UserKnownHostsFile/d >> ~/.ssh/config
    ```
1. Make sure you can SSH into the targets. For example:
   ```shell
   ssh vagrant@target0
   ```
      
Next, install the Puppet modules for the different components of the TIG stack. 

## Install the TIG modules

Before you can use Bolt to install modules, you must install the relevant
modules. The modules you need are all listed in the `bolt-project.yaml` file
under the `modules` key: 

```yaml
name: tig
plans: 
  - tig 

modules:
  - puppet-grafana
  - quadriq-influxdb
  - puppet-telegraf
```

To install the modules and their dependencies, run the
following command:

_\*nix shell command_

```shell
bolt module install
```

_PowerShell cmdlet_

```powershell
Install-BoltModule
```

The `puppet-telegraf` module requires the `toml-rb` Ruby gem. To install the gem, run the following command:

```shell
/opt/puppetlabs/bolt/bin/gem install toml-rb
```

> **Note:** If you're using a version manager like RVM, set your Ruby
> environment to `system` before you install the `toml-rb` gem. For example,
> `rvm use system`.

Next, create an inventory file to specify which targets to use as part of the plan.

## Create an inventory file

Use an inventory file to group and configure the connection settings for your
targets. If you're using existing targets in your system, replace `target0` and
`target1` with your own targets.

The `bolt_tig` directory contains the following inventory file:

```yaml
version: 2
groups:
  - name: dashboard
    targets: 
    - target0
  - name: agents
    targets: 
    - target0
    - target1
config:
  ssh:
    host-key-check: false
    run-as: root
```

The inventory file defines two groups, `dashboard` and `agents`. The `agents`
group includes both targets, while the `dashboard` group only includes
`target0`. The SSH configuration for all targets is defined under `config`.

## Examining the plan

Plans allow you to tie your commands, scripts, and tasks together to create
powerful workflows.

The TIG plan applies three Puppet manifests, which are files that
contain code written in the Puppet language. You can find the manifests in the
`tig_stack/manifests` directory.

The `bolt_tig/plans` directory contains the following `init.pp` plan:

```puppet
plan tig() {

  apply_prep('all')

  apply('dashboard') {
    include tig::dashboard
  }

  $dashboard_host = get_target('dashboard').name

  apply('agents') {
    class{ 'tig::telegraf':
      influx_host => $dashboard_host
    }
  }

  return("Dashboard is live on ${dashboard_host}. Go to http://10.1.0.100:8080 to access your dashboard.")
}
```

The first step in the plan uses the `apply_prep` function to install the
`puppet-agent` package and collect facts from each of the targets in the
inventory file.

Next, an apply block applies the `dashboard` manifest, which installs and
configures both Grafana and InfluxDB. The `dashboard` manifest looks like this:

```puppet
class tig::dashboard (
  String $grafana_password = $tig::params::grafana_password,
  String $grafana_user = $tig::params::grafana_user,
  String $grafana_url = $tig::params::grafana_url,
  String $influx_password = $tig::params::influxdb_password,
  String $influx_database = $tig::params::influxdb_database,
  String $influx_username = $tig::params::influxdb_user,

) inherits ::tig::params {
  class { 'grafana':
    cfg => {
      app_mode => 'production',
      server   => {
        http_port     => 8080,
      },
      security => {
        admin_user => $grafana_user,
        admin_password => $grafana_password,
      },
      database => {
        type          => 'sqlite3',
        host          => '127.0.0.1:3306',
        name          => 'grafananana',
      },
    },
  }

  class {'influxdb': }
  influx_database{$influx_database:
    superuser => $influx_username,
    superpass => $influx_password
  }

  grafana_datasource { 'influxdb':
    require           => Influx_database['bolt'],
    grafana_url       => $grafana_url,
    grafana_user      => $grafana_user,
    grafana_password  => $grafana_password,
    type              => 'influxdb',
    url               => 'http://localhost:8086',
    user              => $influx_username,
    password          => $influx_password,
    database          => $influx_database,
    access_mode       => 'proxy',
    is_default        => true,
  }

  grafana_dashboard { 'telegraf':
    grafana_url       => $grafana_url,
    grafana_user      => $grafana_user,
    grafana_password  => $grafana_password,
    content           => template('tig/dashboards/telegraf.json')
  }
}
```

The `dashboard` manifest inherits a
separate class called `tig::params`, which contains configuration parameters:

```puppet
class tig::params (
  String $influxdb_password,
  String $grafana_password,
  String $influxdb_database = 'bolt',
  String $influxdb_user = 'bolt',
  String $grafana_url = 'http://localhost:8080',
  String $grafana_user = 'bolt',
) {}
```

You can keep the credentials for signing into each service in a separate
location so they're not part of the manifest code. This plan uses a Hiera
implementation uses to store the credentials in `data/common.yaml`:

```yaml
tig::telegraf::database: "bolt"
tig::telegraf::username: "bolt"
# In the real world encrypt these with hiera eyaml or store externally
tig::params::influxdb_password: "hunter2"
tig::params::grafana_password: "boltIsAwesome"
```

> 🔩 **Tip**: For information on Hiera, see [Puppet: About Hiera](https://puppet.com/docs/puppet/latest/hiera_intro.html). 

The second apply block in the TIG plan applies the `manifests/telegraf.pp`
manifest. The `telegraf` manifest installs and configures Telegraf on each of
the agents. This manifest also inherits the `tig::params` class.

```puppet
class tig::telegraf (
  String $influx_host,
  String $password = $tig::params::influxdb_password,
  String $database = $tig::params::influxdb_database,
  String $username = $tig::params::influxdb_user,
) inherits ::tig::params {

  $influx_url = "http://${influx_host}:8086"

  class { 'telegraf':
    hostname => $facts['hostname'],
    outputs  => {
        'influxdb' => [
            {
                'urls'     => [ $influx_url ],
                'database' => $database,
                'username' => $username,
                'password' => $password,
            }
        ]
    },
  }

  telegraf::input{ 'cpu':
    options => [{ 'percpu' => true, 'totalcpu' => true, }]
  }

  ['disk', 'io', 'net', 'swap', 'system', 'mem', 'processes', 'kernel' ].each |$plug| {
    telegraf::input{ $plug:
     options => [{}]}
  }
}
```

The last step in the plan returns results that you can use in other plans or
save for use outside of Bolt. Here, it returns the address for the Grafana
dashboard.

Next, run the plan.

## Run the plan

To run the plan, use the following command

_\*nix shell command_

```shell
bolt plan run tig
```

_PowerShell cmdlet_

```powershell
Invoke-BoltPlan -Name tig
```

Your output should look similar to this:
```
Starting: plan tig
Starting: install puppet and gather facts on target0, target1
Finished: install puppet and gather facts with 0 failures in 47.67 sec
Starting: apply catalog on target0
Finished: apply catalog with 0 failures in 65.3 sec
Starting: apply catalog on target0, target1
Finished: apply catalog with 0 failures in 22.64 sec
Finished: plan tig in 135.65 sec
{
  "grafana_dashboard": "http://10.1.0.100:8080"
}
```

Enter the address from the plan's result into your browser to find the Grafana
dashboard. You can sign in with the following credentials (from
`data/common.yaml`):
- username: `bolt`
- password: `boltIsAwesome`.

Congratulations! You've deployed a TIG Stack with Bolt!

Do you have a real-world use case for Bolt that you'd like to share? Reach out
to us in the #bolt channel on [Slack](https://slack.puppet.com).
