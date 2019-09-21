#  Puppet tasks and plans

Automate your workflow with tasks and plans.

Sometimes you need to do work in your infrastructure that isn't about monitoring and enforcing the desired state of machines. You might need to restart a service, run a troubleshooting script, or get a list of the network connections to a given node. You perform actions like these with Puppet tasks and plans.

## Tasks

Tasks are single actions that you run on target machines in your infrastructure. You use tasks to make as-needed changes to remote systems. You can write tasks in any programming language that can run on the target nodes, such as Bash, Python, or Ruby. Tasks are packaged within modules, so you can reuse, download, and share tasks on the Forge. Task metadata describes the task, validates input, and controls how the task runner executes the task.

## Plans

Plans run a list of Bolt actions in order across multiple nodes. They can compute inputs to an action and process the outputs of execution. This allows you to tie commands, scripts, tasks, plans, and other actions together. You can write plans in the Puppet language or YAML. Like tasks, plans have parameters and are packaged in modules and can be shared on the Forge.

-   **[Inspecting tasks and plans](inspecting_tasks_and_plans.md)**  
Before you run tasks or plans in your environment, inspect them to determine what effect they will have on your target nodes.
-   **[Running tasks](bolt_running_tasks.md#)**  
Bolt can run Puppet tasks on remote nodes without requiring any Puppet infrastructure. 
-   **[Running plans](bolt_running_plans.md#)**  
Bolt can run plans, allowing multiple tasks to be tied together. 
-   **[Installing tasks and plans](installing_tasks_from_the_forge.md#)**  
Tasks and plans are packaged in Puppet modules, so you can install them as you would any module and manage them with a Puppetfile.
-   **[Directory structures for task and plan development](directory_structure.md#)**
Running tasks and plans you've written requires they be placed in a Puppet module. This subject describes several patterns for writing and sharing projects that use tasks and plans.
-   **[Writing tasks](writing_tasks.md#)**  
Tasks are similar to scripts, but they are kept in modules and can have metadata. This allows you to reuse and share them more easily.
-   **[Writing plans in Puppet language](writing_plans.md#)**  
Plans allow you to run more than one task with a single command, compute values for the input to a task, process the results of tasks, or make decisions based on the result of running a task.
-   **[Writing plans in YAML](writing_plans.md#)**  
Simple plans are written in YAML instead of Puppet language.
