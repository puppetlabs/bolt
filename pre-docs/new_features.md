New features
New features added to Bolt in the 0.x release series. 

Breaking change: Bolt requires Ruby 2.3 or higher (0.18.0)
In order to use Bolt you must have Ruby 2.3 or higher installed. You can install Ruby when you install Bolt or directly from ruby-lang.org.

BOLT-381

Command line support for JSON (0.18.0)
On the command line, you can enter JSON data types to pass parameters to your plans and tasks. Parameter values are parsed as JSON when they match the data type, otherwise the original string value is used.

This example passes an array:

bolt task run my_task --nodes all files='["/file1", "file2"]'
bolt plan run my_plan file=["/file1", "file2"] 
If you have want pass a string for a parameter that can accept either a string or typed values, wrap the value in double quotes. 

bolt plan run my_plan bool_or_string='"false"' 
BOLT-260

Support added for Debian 9, discontinued for Debian 7 (0.18.0)
Support for the Linux platform Debian 9 has been added to packaged versions of Bolt. Meanwhile, support for Debian 7 and Debian architecture i386 has been discontinued.

Bolt-374

Support for --no-ssl-verify flag (0.18.0)
Use the --no-ssl-verify flag to connect to a WinRM host using a self-signed certificate.

Bolt-389

ssh key accepted as a string (0.17.2)
The private-key config setting accepts a hash with key-data in addition to a string with the path to the key.

Bolt-379

Pass inventory data via environment variables (0.17.2)
Pass inventory data to Bolt as an environment variable. Instead of writing an inventory file to store information about your nodes, pass this information programmatically to Bolt.

Bolt-377

Added core functions (0.17.2)
The following core functions have been added to Bolt: empty, keys, values, join, flatten, length.

Bolt-373

Support for --query flag (0.17.2)
Use the --query flag to target nodes based on a PuppetDB query. For information on running Puppet Query Language queries using the PuppetDB, see the PQL Reference guide.

Bolt-167

Option to ignore local tasks when using pcp transport (0.17.2)
Bolt defers to orchestrator on task metadata when running tasks via PCP. In practice this means that invalid parameters are reported for each target rather than on the run_task invocation itself.

Bolt-356

Install Bolt from packages (0.17.0)
Packaged versions of Bolt are available on select Linux platforms: Debian 7 and 8, Enterprise Linux 6 and 7, SUSE Linux Enterprise Server (SLES) 12 and Ubuntu 14.04 and 16.04.

To install Bolt from one of these packages:

Install a release package to enable Puppet Platform repositories.

Run the command [pkg-tool name] install bolt. This installs puppet-agent as a dependency and adds a setup PATH to include Bolt.

For more installation information, see Installing Bolt.

Bolt-317

New results summary (0.17.0)
Bolt provides a results summary after running the commands bolt file upload, bolt task run, bolt script run, and bolt command run. The summary lists the nodes that have succeeded and the ones that have failed.
Successful on 5 nodes: tst-vm211,dev-vm291,dev-vm292,stg-vm294,stg-vm295
Failed on 5 nodes: prd-vm190,stg-vm191,stg-vm192,prd-vm194,prd-vm195
Ran on 216 nodes in 13.60 seconds
You can copy one of the comma-separated lists and paste it into an argument to re-run a command on the selected nodes.
BOLT-345

Log file for Bolt results (0.17.0)
You can capture the results of your plan runs in a log file. log has been added to the list of configuration options and includes the following properties:

console or path/to.log: the location of the log output.  

level the type of information in the log. Your options are debug, verbose, notice (default), and warn.

append add the output to an existing log file. Available for only for logs output to a filepath. Your options are true (default) and false.

log:
  console:
    level: :info
  ~/.bolt/debug.log:
    level: :debug
    append: false
BOLT-263

Local transport for Bolt (0.17.0)
Bolt includes a local transport for taking action on your local machine. You can target your machine via the plain string localhost or use the local://...&#39; protocol. Note that anything after local://...&#39; will be ignored. Also if you use localhost as a node or group in your inventory, it will override the shortcut for the local transport. 

BOLT-338

 --nodes has the same value as nodes parameter for bolt plan run (0.17.0)
bolt plan run accepts a --nodes flag, which the same as passing a nodes parameter for the plan. If the plan doesn't accept a nodes parameter an error occurs. Like other commands, you can specify--nodes multiple times to construct a list of nodes as well as to accept a comma-separated list.

BOLT-336

New plans added to Bolt (0.17.0)
Bolt includes three plans for use out-of-the-box: aggregate::count, aggregate::nodes, and canary. Previously, you were required to specify a modulepath to run these plans.

bolt plan run mymodule::myplan --modulepath ./PATH/TO/MODULES
The module path is no longer necessary.

bolt plan run canary <task|command|script>
For more information about these modules, refer to their pages on github.com: https://github.com/puppetlabs/bolt/tree/master/modules/canary and https://github.com/puppetlabs/bolt/tree/master/modules/aggregate.

BOLT-333

Target object stores variables (0.17.0)
A new vars property has been added to the target object. You can assign variables to a target and retrieve them when you run a plan. For more information on how to set and get these variables, see Plan execution functions.

BOLT-332

Nodes in inventory groups accept full URLs (0.16.4)
You can specify full URLs as node names in inventory.
Note: Nodes will pick up inventory config based on the URL that they are created with. If you have a configuration for node1.example.com in your inventory, it will not be used when targeting node1.example.com:2222.
BOLT-337

Target datatype exposes URIs parts (0.16.2)
URI parts are exposed on the Target Datatype, and the TargetSpec type alias is available for plan parameters.

BOLT-342

Wildcards available to target nodes in inventory files (0.16.2)
You can use the * wild card to refer to nodes listed in an inventory file. For example,

bolt task run facts --nodes 'foo*.example.com'
Note that in most shells, the wildcard needs to be quoted or escaped to avoid shell expansion. 

BOLT-330

New get_targets function (0.16.2)
A new Bolt function, get_targets, has been added to resolve a comma-separated string or array of node URIs and/or groups into an array of Target objects.

BOLT-318

Improvements to pcp transport (0.16.2)
The pcp transport will run a task, command, script, or file upload on all nodes in a single job in the orchestrator, instead of one job per node.

BOLT-316

Improved error handling for plans (0.16.1)
Bolt has improved error handling for plans. You can create detailed error messaging and apply conditions under which a plan should continue or fail.

For more information, see Success and failure in plans.

BOLT-123

New inventory file (0.16.1)
A new inventory file (inventory.yaml) has been added to Bolt. You can use it to organize your nodes into groups or set up connection information for nodes or groups of nodes.

BOLT-104

Insecure option changed to no-host-key-check for SSH and no-ssl for WinRM (0.16.0)
Potential breaking change for Bolt commands. The --insecure and -k options are no longer available. They have been replaced with no-check-host-keys and check-host-keys options for the SSH transport and no-ssl and sll options for WinRM.

BOLT-290

Usage information added to bolt plan show <plan-name> output (0.16.0)
The output for bolt plan show <plan-name> includes usage information for running a plan.

BOLT-304

_run_as parameter added to run_* functions (0.16.0)
Using the _run_as parameter, you can indicate a user when running the following functions: run_task, run_command, run_script, and run_plan.

BOLT-292

Bolt terminates the calling process (exit 2) when some nodes fail (0.15.0)
Bolt terminates the process (exit 2) when run command, run script, run task, or file upload fails on some nodes.

BOLT-209

Standardize Target object (0.15.0)
This is a breaking change. The host method has been moved to uri.

BOLT-289

run_* functions abort on error (0.15.0)
This is a breaking change. The run functions in Bolt plans raise an exception if they fail on any nodes. To catch these and return the result set, pass the '_catch_errors' => true option at the end of run function call.

BOLT-222

New ResultSet object behaves like an array rather than a hash (0.15.0)
This is a breaking change. The run_command, run_script, run_task, and upload_file functions return a ResultSet object that behaves like an array of Result objects rather than a hash of Variant[Data, Error] objects. 

Plans and functions that interacted with ExecutionResult must be updated to interact with ResultSet instead. 

BOLT-286

Actions run from a plan are logged (0.14.0)
Information about actions run from a plan are logged at the notice level, which is visible by default. This provides good default logging for progress during a plan.

BOLT-266

Bolt runs any script with an extension handler on Windows (0.14.0)
Previously for WinRM targets, Bolt would only run scripts and tasks with the extensions .ps1, .pp, or .rb. For others, Bolt attempted to run as a PowerShell script. Now Bolt will reject scripts that don't end in those 3 extensions by default. You can enable more extensions by adding them to your Bolt config, as follows:
winrm:
   extensions: [.py, .pl]
You must also ensure the target host has the file type registered for that extension, as well as a way to run it.

BOLT-295

--run-as can be set under SSH config section (0.13.0)
You can set --run-as under the SSH configuration section as "run-as: <USER>"

New configuration options available via Bolt config file (0.12.0)
The connections settings for the orchestrator can be specified in the Bolt config file instead of being read from client-tools/orchestrator.conf. The Bolt config can also specify which environment tasks should be loaded from in the orchestrator.

For more information, see the PCP transport options in Bolt configuration options.

New commands to display documentation (0.12.0)
bolt task show - lists available tasks. You can add a specific task name to display documentation for an installed task: bolt task show <TASK NAME>

bolt plan show - lists the available plans in the current module path.

New Bolt options (0.12.0)
Bolt accepts a --noop option that can be used with task run to run the task in noop mode.

Bolt offers new WinRM and PCP configuration options.

Bolt takes .yaml and .yml cofig files (0.11.0)
Bolt looks for config files called either bolt.yaml or bolt.yml. If both exist, you will get a warning. Bolt prioritizes bolt.yaml.

Connection timeout is configurable (0.11.0)
Use the --connect-timeout flag or transport configuration option to configure the timeout for connecting to WinRM and SSH targets.

Bolt-163

Configure the temporary directory for scripts and tasks per node (0.11.0)
The tmpdir used to upload and execute scripts and tasks can be configured by the --tmpdir flag and transport option. This enables Bolt to be used if the tempdir is mounted noconfig or is not available over SSH.

Bolt-147

Task parameters are validated (0.11.0)
When tasks are run directly with bolt task run, they are validated. As a result, tasks that have invalid parameter types might fail.

Bolt-66

Bolt config file for common options (0.10.0)
You can create a config file to store and automate the CLI flags you use every time you run Bolt. Bolt will load config options from a file ~/.puppetlabs/bolt.yml or the path specified on the command line with --configfile.

New input method: powershell
The new powershell input method enables Bolt to call PowerShell tasks with the native PowerShell input method. It changes the default input method for .ps1 tasks. Any tasks that rely on environment variables need to include those in metadata to continue working with Bolt.

Bolt supports SCP for file transfer (0.9.0)
Bolt uses SCP to copy files to SSH targets instead of SFTP. This means targets no longer need SFTP configured.

Bolt supports a --private_key flag (0.9.0)
The --private_key flag enables you to specify the private key file to use with SSH transport.

Bolt doesn't invoke new powershell instances (0.9.0)
This change improves the performance of the WinRM transport by running PowerShell-based Bolt scripts and tasks in the connected WinRM session, rather than creating new PowerShell processes. This change also fixes an issue with properly reflecting failure status on PowerShell versions older than PowerShell 5. You should not rely on variables set between commands persisting, even those set in the $global scope. Users should not rely on [Console]::WriteLine to produce output from PowerShell code.

Improved output for Bolt command, script, and task runs (0.9.0)
Bolt displays human readable results when running commands and scripts by default, or when you specify -f human on the command line.

Bolt added WinRM enhancements (0.8.0)
WinRM nodes run arbitrary whitelisted scripts by extension. Bolt previously only treated WinRM script execution as PowerShell code. To behave more like task execution, scripts use the same file extension-based whitelist to determine which executable should run a given file type. This allows .rb scripts to be run with Ruby, .pp files to be run with Puppet, and .ps1 files to be run with PowerShell. [BOLT-208]

Improved error messaging. For example, when running a script or task over WinRM, Bolt failed with an obscure message when the interpreter necessary to execute the file was unavailable. [BOLT-202]

Display results as they occur, instead of when all nodes finish (0.8.0)
Bolt displays results for each node as an operation--command, script, task, or plan--completes, rather than waiting for all node operations to complete. This way, you can abort the operation if something goes wrong. [BOLT-151]

New sudo and sudo password prompt support (0.8.0)
New sudo and sudo password prompt allow Bolt to run commands, scripts, and tasks as a different user than the SSH connection. There are three new command-line flags associated with it:

run_as enables user to run as if using privilege escalation

sudo enables program to execute for privilege escalation

sudo_password enables password for privilege escalation

[BOLT-98]

Output as JSON when user requests JSON (0.8.0)
Bolt added a --format flag to switch the output format to JSON by setting --format=json when running a command, script, or task. [BOLT-45]

Bolt passes arguments to scripts (0.7.0) 
You can pass arguments to a script when using the bolt script run command. Arguments are passed literally and are not interpolated by the shell on the remote host. For usage information, see running scripts. [BOLT-52]

Command line option for --transport added (0.7.0)
This release adds a command line option, --transport, for specifying the default transport. This is useful on Windows, so that you don't have to specify winrm for each node. The transport can be overridden on a per-host basis. For usage information, see setting a default transport. [BOLT-53]

Bolt can run .pp tasks with Puppet on Windows (0.7.0)
If a task is written in the Puppet language and has a .pp file extension, then Bolt executes the task using C:\Program Files\Puppet Labs\puppet\bin\puppet apply on the remote Windows nodes. For *nix nodes, the task must include a shebang line specifying the interpreter, such as #!/opt/puppetlabs/puppet/bin/puppet apply. [BOLT-158]

Kereberos support added (0.7.0)
Bolt supports the SSH authentication method gssapi-with-mic. To use this functionality, you must install the net-ssh-krb gem separately on your workstation, and ensure that gssapi-with-mic is included in the PreferredAuthentications option in your ~/.ssh/config. [BOLT-168]

Use shell shortcuts to create node lists (0.7.0)
You can generate node lists with shell shortcuts and brace expansion with the --nodes flag on the command line. This works with all Bolt commands except bolt run plan. For usage details, see the topic about specifying nodes. [BOLT-196]

New --modulepath option can accept multiple directories (0.7.0)
The --modules command line option has been renamed to --modulepath. This option accepts multiple directories joined by a semi-colon (;) on Windows and a colon (:) on all other platforms. The option does not have a default and must be specified when running tasks and plans. [BOLT-122]

Bolt can accept node lists from a file or as standard input (0.6.0)
Bolt accepts node lists from a file or from stdin. See the topic about specifying nodes with Bolt for usage information. [BOLT-29]

Bolt can securely prompt for a password (0.6.0)
If you run a Bolt command with the --password or -p flag, but do not specify a value, Bolt securely prompts for the password. This prevents the password from appearing in a process listing or on the console. [BOLT-28]

Command line options apply to plan run command (0.6.0)
Bolt applies command line options, such as --user, when executing a plan with bolt plan run. This enables executing plans on Windows nodes over WinRM and on *nix nodes when using password-based authentication. [BOLT-183]