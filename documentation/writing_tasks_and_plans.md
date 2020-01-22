# Tasks and plans

Automate your workflow with tasks and plans.

Sometimes you need to do work in your infrastructure that isn't about monitoring and enforcing the desired state of machines. You might need to restart a service, run a troubleshooting script, or get a list of the network connections to a given target. You perform actions like these with Puppet tasks and plans.

## Tasks

Tasks are single actions that you run on target machines in your infrastructure. You use tasks to make as-needed changes to remote systems.

You can write tasks in any programming language that can run on the targets, such as Bash, Python, or Ruby. Tasks are packaged within modules, so you can reuse, download, and share tasks on the Forge. Task metadata describes the task, validates input, and controls how the task runner executes the task.

## Plans

Plans are sets of tasks that can be combined with other logic. This allows you to do complex task operations, such as running multiple tasks with one command, computing values for the input for a task, or running certain tasks based on results of another task. You write plans in the Puppet language. And like tasks, plans are packaged in modules and can be shared on the Forge.

-   **[Inspecting tasks and plans](inspecting_tasks_and_plans.md)**
    
    Before you run tasks or plans in your environment, inspect them to determine what effect they have on your targets.

-   **[Running tasks](bolt_running_tasks.md#)**  
    
    Bolt can run Puppet tasks on remote targets without requiring any Puppet infrastructure. 

-   **[Running plans](bolt_running_plans.md#)**  
    
    Bolt can run plans, allowing multiple tasks to be tied together. 

-   **[Installing modules](bolt_installing_modules.md#)**  
    
    Tasks and plans are packaged in Puppet modules, so you can install them as you would any module and manage them with a Puppetfile. 

-   **[Directory structures for tasks and plans](directory_structure.md#)**  
    
    Puppet tasks, plans, functions, classes and types must exist inside a Puppet, module in order for Bolt to load them. Bolt loads modules by searching for module directories on the modulepath.

-   **[Writing tasks](writing_tasks.md#)**  
    
    Bolt tasks are similar to scripts, but they are kept in modules and can have metadata. This allows you to reuse and share them.

-   **[Writing plans in Puppet language](writing_plans.md#)**  
    
    Plans allow you to run more than one task with a single command, compute values for the input to a task, process the results of tasks, or make decisions based on the result of running a task.
    
-   **[Writing plans in YAML](writing_yaml_plans.md#)**  
    
    YAML plans run a list of steps in order, which allows you to define simple workflows. Steps can contain embedded Puppet code expressions to add logic where necessary.
