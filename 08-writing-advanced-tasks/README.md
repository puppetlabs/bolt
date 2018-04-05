# Writing advanced tasks

> **Difficulty**: Intermediate

> **Time**: Approximately 10 minutes

In this exercise you will write a task with metadata. 

# Prerequisites
Complete the following before you start this lesson:

1. [Installing Bolt](../01-installing-bolt)
1. [Acquiring nodes](../02-acquiring-nodes)
1. [Writing tasks](../05-writing-tasks)

# About task metadata
Task metadata files describe task parameters, validate input, and control how tasks are executed.  Adding metadata to your tasks helps others use them.  You write metadata for a task in JSON and save it with the same name as your task. For example, if you write a task called `great_metadata.py` its corresponding metadata file is named `great_metadata.json`.  

# Writing your first task with metadata
Write a simple task that formats the parameters a user gives it.

1. Save the following file to `modules/exercise8/tasks/great_metadata.py`:

    ```
    #!/usr/bin/env python
    
    """
    This script prints the values and types passed to it via standard in.  It will
    return a JSON string with a parameters key containing objects that describe
    the parameters passed by the user.
    """
    
    import json
    import sys
    
    def make_serializable(object):
      if isinstance(object, unicode):
        return object.encode('utf-8')
      else:
        return object
    
    data = json.load(sys.stdin)
    
    message = "Congratulations on writing your metadata!  Here are the keys and the values that you passed to this task."
    
    result = {'message': message, 'parameters': []}
    for key in data:
        k = make_serializable(key)
        v = make_serializable(data[key])
        t = type(data[key]).__name__
        param = {'key': k, 'value': v, 'type': t}
        result['parameters'].append(param)
    
    print(json.dumps(result))
    ```

2. Write the accompanying metadata and save the file to `modules/exercise8/tasks/great_metadata.json`. Specify the parameters as types such as `"type": "Integer"`  which help validate user input as an `Integer`.  

    ```
    {
      "description": "An exercise in writing great metadata",
      "input_method": "stdin",
    
      "parameters": {
        "name": {
          "description": "The description for the 'name' parameter",
          "type": "String"
        },
        "recursive": {
          "description": "The description for the 'recursive' parameter",
          "type": "Boolean"
        },
        "action": {
          "description": "The description for the 'action' parameter",
          "type": "Enum[stop, start, restart]"
        },
        "timeout": {
          "description": "The description for the 'timeout' parameter",
          "type": "Optional[Integer]"
        }
      }
    }
    ```

# Using your task with metadata

1. Run 'bolt task show' to verify that the task you created appears with its description in the list of available tasks.

    ```
    bolt task show --modulepath ./modules
    ```
    The result:
    ```     
    ...
    exercise8::great_metadata     An exercise in writing great metadata
    facter_task                   Inspect the value of system facts
    install_puppet                Install the puppet 5 agent package
    ...
    ```

2. Run `bolt task show <task-name>` to view the parameters that your task uses.

    ```
    bolt task show exercise8::great_metadata --modulepath ./modules
    ```
    The result:
    ```    
    exercise8::great_metadata - An exercise in writing great metadata
    
    USAGE:
    bolt task run --nodes, -n <node-name> exercise8::great_metadata name=<value> [user=<value>] password=<value> action=<value>
    
    PARAMETERS:
    - name: String
        The description for the 'name' parameter
    - recursive: Boolean
        The description for the 'password' parameter
    - action: Enum['restart', 'start', 'stop']
        The description for the 'action' parameter
    - timeout: Optional[Integer]
        The description for the 'timeout' parameter
    ```

# Testing your task's metadata validation

Bolt can use the types that you have specified in your metadata to validate parameters passed to your task.  Run your task with an incorrect value for the `action` parameter and see what happens.  

1. Run your task and pass the following parameters as a JSON string.

    ```
    bolt task run exercise8::great_metadata --nodes all --modulepath ./modules --params '{"name":"poppey","action":"spinach","recursive":true}'
    ```
    The result:
    ```     
    Task exercise8::great_metadata:
     parameter 'action' expects a match for Enum['restart', 'start', 'stop'], got 'spinach'
    ```

2. Correct the value for the action parameter and run the task again.
    ```
    bolt task run exercise8::great_metadata --nodes all --modulepath ./modules --params '{"name":"poppey","action":"start","recursive":true}'
    ```
    The result:
    ```     
      {
        "message": "Congratulations on writing your metadata!  Here are the keys and the values that you passed to this task.",
        "parameters": [
          {
            "type": "unicode",
            "value": "start",
            "key": "action"
          },
          {
            "type": "unicode",
            "value": "poppey",
            "key": "name"
          },
          {
            "type": "bool",
            "value": true,
            "key": "recursive"
          }
        ]
      }
    Ran on 1 node in 0.73 seconds
    ```

# Creating a task that supports no-operation mode (noop)

You can write tasks that support no-operation mode (noop). You use noop to see what changes a task would make, but without taking any action.

1. Create the metadata for the new task and save it to `modules/exercise8/tasks/file.json`:

    ```
    {
      "description": "Write content to a file.",
      "supports_noop": true,
      "parameters": {
        "filename": {
          "description": "the file to write to",
          "type": "String[1]"
        },
        "content": {
          "description": "The content to write",
          "type": "String"
        }
      }
    }
    ```

2. Save the following file to `modules/exercise8/tasks/file.py`. This task uses input from stdin. When a user passes the `--noop` flag, the JSON object from stdin will contain the `_noop` key with a value of True.  

    ```
    #!/usr/bin/env python
    
    """
    This script attempts the creation of a file on a target system. It will
    return JSON string describing the actions it performed.  If passed "{"_noop": True}"
    on stdin it will check to see if it can write the file but not actually write it.
    """
    
    import json
    import os
    import sys
    
    params = json.load(sys.stdin)
    filename = params['filename']
    content = params['content']
    noop = params.get('_noop', False)
    
    exitcode = 0
    
    def make_error(msg):
      error = {
          "_error": {
              "kind": "file_error",
              "msg": msg,
              "details": {},
          }
      }
      return error
    
    try:
      if noop:
        path = os.path.abspath(os.path.join(filename, os.pardir))
        file_exists = os.access(filename, os.F_OK)
        file_writable = os.access(filename, os.W_OK)
        path_writable = os.access(path, os.W_OK)
    
        if path_writable == False:
          exitcode = 1
          result = make_error("Path %s is not writable" % path)
        elif file_exists == True and file_writable == False:
          exitcode = 1
          result = make_error("File %s is not writable" % filename)
        else:
          result = { "success": True , '_noop': True }
      else:
        with open(filename, 'w') as fh:
          fh.write(content)
          result = { "success": True }
    except Exception as e:
      exitcode = 1
      result = make_error("Could not open file %s: %s" % (filename, str(e)))
    print(json.dumps(result))
    exit(exitcode)
    
    ```

3. Test the task with the `--noop` flag.
    ```
    bolt task run exercise8::file --nodes all --modulepath ./modules content=Hello_World filename=/tmp/hello_world --noop
      {
        "_noop": true,
        "success": true
      }
    Ran on 1 node in 0.64 seconds
    ```
    
4. Run the task again without `--noop` and see the task create the file successfully.
    ```
    bolt task run exercise8::file --nodes all --modulepath ./modules content=Hello_World filename=/tmp/hello_world
    ```
    The result:
    ```       {
        "success": true
      }
    Ran on 1 node in 0.63 second
    ```
# Next steps

Now that you know how to write task metadata and include the `--noop` flag you can move on to:

1. [Writing advanced Plans](../09-writing-advanced-plans)
