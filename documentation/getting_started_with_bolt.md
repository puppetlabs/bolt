# Getting started with Bolt

Welcome to _Getting started with Bolt!_ Bolt is an open source orchestration
tool that helps you make on-demand changes to remote targets such as servers,
network devices, and cloud services.

In this guide, you'll learn to write a Bolt plan that installs Apache on a
group of target machines and uploads a customized home page. Bolt plans are
powerful workflows that allow you to string together and automate commands,
scripts, tasks, and even other plans.

After you've completed this guide, you'll know how to:
- Set up a Bolt project directory.
- Run a Bolt command on a target.
- Create an inventory file to set up groups and add connection information for
  your targets.
- Write a Bolt plan that uses a script and a task, and uploads a file to your
  targets.

Before you begin:
- Make sure you've installed Bolt on your machine. For instructions on how to
  install Bolt on your operating system, see
  [Installing Bolt](./bolt_installing.md).
- Make sure you've [installed Docker](https://docs.docker.com/get-docker/).
  Bolt does not require Docker to run, but for the purposes of this guide,
  Docker containers offer a safe and relatively simple way to set up some
  targets to practice on.

## Create a Bolt project and set up targets

A Bolt project is a directory containing a `bolt.yaml` file. The `bolt.yaml`
file contains project-wide configuration settings. Your `my_project` directory
must contain a `bolt.yaml` file so that Bolt recognizes it as a Bolt project.

### Create a Bolt project directory

Use the `bolt project init` command to create a project directory named
`my_project`:

```bash
bolt project init ./my_project
```

Listing the contents of `my_project` shows a `bolt.yaml` file:

```bash
$ ls my_project
bolt.yaml
```

To use Bolt plans or tasks, your Bolt project must use a specific directory
structure. The directory structure of a Bolt project is closely tied to
[Puppet modules](https://puppet.com/docs/puppet/latest/modules_fundamentals.html).
Because your plan will install Apache, you need an `apache` module directory.
Run the following command to set up the required directories in your project
folder:

```bash
mkdir -p site-modules/apache/plans site-modules/apache/files
```

After running the command, the file structure of `my_project` looks like this:
```bash
.
├── bolt.yaml
└── site-modules
    └── apache
        ├── files
        └── plans
```

Next, set up Docker targets to run Apache on.

### Create your targets
Bolt connects directly to computers, or _targets_, using Secure Shell (SSH) or
Windows Remote Management (WinRM). To see how a Bolt plan works, you'll build
and run some Docker containers to use as targets.

In the root of your `my_project` directory, create a file named `Dockerfile`
and paste in the following:

```bash
FROM rastasheep/ubuntu-sshd
RUN apt-get update && apt-get -y install libssl-dev
EXPOSE 80
CMD ["/usr/sbin/sshd", "-D"]
```

This Dockerfile defines an Ubuntu container with an SSH service running. The
SSH service allows Bolt to communicate with the container using the SSH
transport.

> 🔩 **Tip**: A transport defines the connection method that Bolt uses to
  connect to a target. There is a Docker transport that simplifies connecting
  to Docker containers, but the SSH transport is useful for gaining a broader
  understanding of how Bolt inventory files work.

Next, build a `docker-compose.yaml` file to create two instances of the
container. In your `my_project` directory, create the following file and name
it `docker-compose.yaml`:

```yaml
version: '3'
services:
  target1:
    build: .
    ports:
      - '3000:80'
      - '2000:22'
    container_name: target1
  target2:
    build: .
    ports:
      - '3001:80'
      - '2001:22'
    container_name: target2
```

This compose file creates two containers using the Dockerfile. The containers
are named `target1` and `target2`, and are bound to ports `2000` and `2001`,
respectively, for SSH connections, and ports `3000` and `3001` for HTTP
connections.

After creating your Dockerfile and `docker-compose.yaml` file, your file
structure looks like this:

```bash
.
├── Dockerfile
├── bolt.yaml
├── docker-compose.yaml
└── site-modules
    └── apache
        └── files
        └── plans
```

Build and run your containers using the `docker-compose` command:

```bash
docker-compose up -d --build
```

You can check that your containers are running using the `docker-compose ps`
command:

```bash
$ docker-compose ps
Name          Command        State                     Ports
--------------------------------------------------------------------------------
target1   /usr/sbin/sshd -D   Up      0.0.0.0:2000->22/tcp, 0.0.0.0:3000->80/tcp
target2   /usr/sbin/sshd -D   Up      0.0.0.0:2001->22/tcp, 0.0.0.0:3001->80/tcp
```

Your targets are ready. Next, run a command on a target to see how Bolt works.

## Run a command on a target

Before you start writing a plan, try using Bolt to run a command on one of your
targets. The syntax to run a Bolt command is `bolt command run <COMMAND>
--targets <TARGET_NAME> <OPTIONS>`.

Use the following command to run `whoami` on `target1`:

```bash
bolt command run whoami -t 0.0.0.0:2000 -u root -p root --no-host-key-check
```

This command targets `0.0.0.0:2000`, which is the IP address and SSH port for
the `target1` container. The command also specifies `root` as the username and
password, and includes the `--no-host-key-check` option to turn off certificate
authentication.

After you run the command, you get the following output from `whoami`:

```bash
$ bolt command run whoami -t 0.0.0.0:2000 -u root -p root --no-host-key-check
Started on 0.0.0.0:2000...
Finished on 0.0.0.0:2000:
  STDOUT:
    root
Successful on 1 target: 0.0.0.0:2000
Ran on 1 target in 0.46 sec
```

You've run your first Bolt command on a target! Next, create an inventory file
to group your targets together and simplify your Bolt commands.

## Create an inventory file to group your targets

You've just run a command on a single target. You could use the same command
with a comma-separated list to target both of your containers. However, as the
number of targets grows, this approach quickly becomes cumbersome. For example,
imagine a situation where you need to use different passwords or certificates
for different targets.

An inventory file is useful for handling this complexity. With an inventory
file, you can set up different connection settings for each of your targets,
and group targets together so you can aim a command at the group instead of
specifying targets in a list.

Create a file named `inventory.yaml` in your project directory and paste in the
following:

```yaml
groups:
- name: containers
  targets:
    - uri: 0.0.0.0:2000
      name: target1
    - uri: 0.0.0.0:2001
      name: target2
  config:
    transport: ssh
    ssh:
      user: root
      password: root
      host-key-check: false
```      

This inventory file contains a group called `containers` that lists the Uniform
Resource Identifier (URI) and name for each Docker container, as well as the
transport that Bolt is using to communicate with the containers (SSH), and the
SSH authentication settings.

At this point, your file structure looks like this:

```bash
.
├── Dockerfile
├── bolt.yaml
├── docker-compose.yaml
├── inventory.yaml
└── site-modules
    └── apache
        ├── files
        └── plans
```

To test your inventory file, run the same `whoami` command on `target1`:

```bash
bolt command run whoami -t target1
```

Notice how much shorter the command is now that the inventory file is handling
connection details like the user, password, ports, and URIs.

> 🔩 **Tip**: You can run a Bolt command on all of the targets in your inventory
 using the top-level `all` group. To target the `all` group, use the command: `bolt
 command run <COMMAND> -t all`.

Next, write a Bolt plan to install Apache on your targets.

## Write a Bolt plan

Plans allow you to tie your commands, scripts, and tasks together to create
powerful workflows. You can write Bolt plans in the Puppet language, or use
YAML. In this guide, you're going to write a YAML plan that installs the Apache
package on your Docker targets, starts the Apache service, and uploads an HTML
homepage.

### Use a task to install Apache on your targets

The first step in your YAML plan uses a Puppet task to install Apache on your
targets.

In your `my_project/site-modules/apache/plans` directory, create the following
file and name it `install.yaml`:

```yaml
parameters:
  targets:
    type: TargetSpec

steps:
  - name: install_apache
    task: package
    targets: $targets
    parameters:
      action: install
      name: apache2
    description: "Install Apache using the packages task"
```

After creating `install.yaml`, your file structure looks like this:

```bash
.
├── Dockerfile
├── bolt.yaml
├── docker-compose.yaml
├── inventory.yaml
└── site-modules
    └── apache
        ├── files
        └── plans
            └── install.yaml
```            

The first section of a Bolt plan defines the parameters your plan accepts. So
far, this plan has one parameter, `targets`, with the type `TargetSpec`. The
`TargetSpec` type is a wrapper for defining targets and allows you to pass a
target, or multiple targets, into a plan. When you run this plan from the
command line and use the `--targets` argument, Bolt interpolates the targets
into the `targets` parameter.

After the `parameters` section, you define the steps that make up the body of
your plan. The first step in your plan is named `install_apache`. This step
uses a Bolt task called `package` to install Apache on your targets. A Bolt
task is a script that has been packaged into a Puppet module. The `package`
task comes prepackaged with Bolt and allows you to perform various
package-related actions. Bolt tasks are useful because you can reuse them or
share them with others. Many of the modules on the Puppet forge include Bolt
tasks.

In addition to the name of the task and the targets that Bolt will execute the
task on, the step also includes a `parameters` section to tell the task what
action to perform (`install`), and the name of the package that Bolt should
install (`apache2`). The step also includes an optional `description` key.

Run the plan on your containers group using the following command:

```bash
bolt plan run apache::install -t containers
```

> **Note**: The name of this plan consists of two segments joined by a double
  colon. The first segment indicates the name of the module where the plan is
  located, and the second segment is the name of the plan file without the
  extension. Your plan is located in the `apache` module directory and is named
  `install.yaml`, so the name of the plan is `apache::install`.

The output looks like this:

```bash
$ bolt plan run apache::install -t containers
Starting: plan apache::install
Starting: task package on target1, target2
Finished: task package with 0 failures in 18.74 sec
Finished: plan apache::install in 18.77 sec
Plan completed successfully with no result
```

Next, run a script on your targets to start the Apache service.

### Run a script on your targets

Because you're running Apache on containers, the Apache service does not start
automatically. You must create a short bash script that starts the Apache
service and add it to your plan as a script step.

Create a file named `start_apache.sh` in
`my-project/site-modules/apache/files/` and enter the following script:

```bash
#!/usr/bin/env bash

i=`ps -eaf | grep -i apache | grep -v grep | grep -v bash | wc -l`

if [[ $i > 0 ]]
then
  echo "Apache is running"
else
  echo "Starting Apache"
  apache2ctl start
fi
```

At this point, your file structure looks like this:

```bash
.
├── Dockerfile
├── bolt.yaml
├── docker-compose.yaml
├── inventory.yaml
└── site-modules
    └── apache
        ├── files
        │   └── start_apache.sh
        └── plans
            └── install.yaml
```

The script checks the processes running on the container for Apache and starts
the service if it is not running.

Now, add the script to `install.yaml` as a step. After the `install_apache`
step, paste the following:

```yaml
- name: start_apache
  script: apache/start_apache.sh
  targets: $targets
  description: "Starting Apache service"
``` 

The step calls the `start_apache.sh` script from your apache module directory.
Because the file is in your `<MODULE_NAME>/files` location, you can use the
syntax `<MODULE_NAME>/<FILE_NAME>` instead of typing out the full path to the
script.

Your plan now looks like this:

```yaml
parameters:
  targets:
    type: TargetSpec

steps:
  - name: install_apache
    task: package
    targets: $targets
    parameters:
      action: install
      name: apache2
    description: "Install Apache using the package task"

  - name: start_apache
    script: apache/start_apache.sh
    targets: $targets
    description: "Start the Apache service"
```

Run the plan again:

```bash
bolt plan run apache::install -t containers
```

At this point, you can reach either of your targets in your web browser using
their UID followed by port `3000` for `target1`, or port `3001` for `target2`.
Go to [0.0.0.0:3000](http://0.0.0.0:3000) to see Apache's default Ubuntu
homepage on `target1`.

You have two functioning Apache servers. Next, upload a file to your targets to
change the homepage.

### Upload an HTML homepage to your targets

Now that Apache is installed on both of your containers, upload an HTML
homepage for the targets to display.

In `my_project/site-modules/apache/files/`, create a file named `index.html`
and enter the following:

```html
<html>
  <head>
    <title> Getting started with Bolt </title>
  </head>
  <body>
    <h1>Success!</h1>
    <p>I'm running this website on a server configured with Bolt!</p>
  </body>
</html>
```                                                                                                           

Your final file structure looks like this:

```bash
.
├── Dockerfile
├── bolt.yaml
├── docker-compose.yaml
├── inventory.yaml
└── site-modules
    └── apache
        ├── files
        │   ├── index.html
        │   └── start_apache.sh
        └── plans
            └── install.yaml
```

Before you add a step to upload your homepage to your containers, you must
define another parameter. In the `parameters` section of `install.yaml`, add a
parameter named `src` with the type `String`. The `src` parameter is the
location of the file you want to upload. You'll pass in `src` as an argument
when you run the plan.

The `parameters` section of your plan now looks like this:

```yaml
parameters:
  targets:
    type: TargetSpec
  src:
    type: String
...
```                                                                                      

Now add the following step after the `start_apache` step:

```yaml
- name: upload_homepage
  source: $src
  destination: /var/www/html/index.html
  targets: $targets
  description: "Upload homepage"      
```                                                                                                     

The `upload_homepage` step uploads a file from the path you specify to a
destination path on the specified targets.

Your final plan looks like this:

```yaml
parameters:
  targets:
    type: TargetSpec
  src:
    type: String  

steps:
  - name: install_apache
    task: package
    targets: $targets
    parameters:
      action: install
      name: apache2
    description: "Install Apache using the package task"

  - name: start_apache
    script: apache/start_apache.sh
    targets: $targets
    description: "Start the Apache service"

  - name: upload_homepage
    source: $src
    destination: /var/www/html/index.html
    targets: $targets
    description: "Upload site contents"                            
```

This time, run the plan with the `src` argument to give Bolt a path to the
homepage file you want to upload:

```bash
bolt plan run apache::install -t containers src=apache/index.html
```

> **Remember**: Because the file is in your `<MODULE_NAME>/files` location,
  you can use the syntax `src=<MODULE_NAME>/<FILE_NAME>` instead of typing in
  the full path to the file.

Go to [0.0.0.0:3000](http://0.0.0.0:3000) again to see your new index page.

> **Note**: If the page hasn't changed from the default Ubuntu homepage, try a
  hard refresh to clear the page's cache. On most browsers, you can accomplish
  this by holding **Shift** and clicking **Reload**.

Congratulations! You've learned how to run commands and scripts with Bolt,
you've created a Bolt project with an inventory file, and you've written and
run a Bolt plan that installs Apache on your targets and uploads a customized
homepage.

**Continue learning about Bolt:**
- For a deeper dive into Bolt, try the
  [Introduction to Bolt](https://learn.puppet.com/course/puppet-orchestration-bolt-and-tasks)
  training course or the
  [Bolt learning kit](https://puppet.com/learning-training/kits/intro-to-bolt/).
- For more information on working with Windows targets, see
  [Automating Windows targets](./bolt_examples.md).
- To find out more about Bolt plans, see
  [Orchestrating workflows with plans](./plans.md).
- For a list of available Bolt transports, see
  [Running Bolt commands](./running_bolt_commands.md).
- To learn about Bolt tasks, see
  [Making on-demand changes with tasks](./tasks.md).
- To find Puppet modules that use tasks, take a look at the
  [Puppet Forge](https://forge.puppet.com/).
- For information on the settings you can use in `bolt.yaml`, see
  [Bolt configuration options](./bolt_configuration_reference.md).