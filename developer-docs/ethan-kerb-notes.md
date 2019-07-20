#### Notes

* looks like the failures in interop are somewhere around:

> httpauth.c line 2145
https://github.com/microsoft/omi/blob/049c361978731425549f35067ab25b0b14febd01/Unix/http/httpauth.c#L2145

> httpauth.c line 894
https://github.com/microsoft/omi/blob/049c361978731425549f35067ab25b0b14febd01/Unix/http/httpauth.c#L894

*  in gssapi-1.3.0 gem -> lib_gssapi_loader.rb changes tried on OSX

in MIT loading

```
  when /darwin/
    # TODO: Ethan change
    gssapi_lib = '/usr/lib/libgssapi_krb5.dylib'
    # using *new* Kerberos lib results in the error:
    # Cannot contact any KDC for realm 'BOLT.TEST'
    # gssapi_lib = '/usr/local/opt/krb5/lib/libgssapi_krb5.dylib'
```

in Heimdal loading
```
  when /darwin/
    # gssapi_lib = '/usr/heimdal/lib/libgssapi.dylib'
    gssapi_lib = '/usr/local/opt/heimdal/lib/libgssapi.dylib'
```

- these paths should be configurable


### Other Error

Not sure if this stack trace is still valid or not... but the `undefined method 'text'` seems odd

```
undefined method `text' for nil:NilClass


/home/centos/source/bolt/.bundle/gems/ruby/2.5.0/gems/winrm-2.3.1/lib/winrm/shells/power_shell.rb:108:in `block in send_command'
/home/centos/source/bolt/.bundle/gems/ruby/2.5.0/gems/winrm-2.3.1/lib/winrm/psrp/message_fragmenter.rb:51:in `fragment'
/home/centos/source/bolt/.bundle/gems/ruby/2.5.0/gems/winrm-2.3.1/lib/winrm/shells/power_shell.rb:104:in `send_command'
/home/centos/source/bolt/.bundle/gems/ruby/2.5.0/gems/winrm-2.3.1/lib/winrm/shells/base.rb:129:in `with_command_shell'
/home/centos/source/bolt/.bundle/gems/ruby/2.5.0/gems/winrm-2.3.1/lib/winrm/shells/base.rb:79:in `run'
/home/centos/source/bolt/lib/bolt/transport/winrm/connection.rb:125:in `execute'
/home/centos/source/bolt/lib/bolt/transport/winrm.rb:87:in `block in run_command'
/home/centos/source/bolt/lib/bolt/transport/winrm.rb:69:in `with_connection'
/home/centos/source/bolt/lib/bolt/transport/winrm.rb:86:in `run_command'
/home/centos/source/bolt/lib/bolt/transport/base.rb:143:in `block in batch_command'
/home/centos/source/bolt/lib/bolt/transport/base.rb:71:in `with_events'
/home/centos/source/bolt/lib/bolt/transport/base.rb:141:in `batch_command'
/home/centos/source/bolt/lib/bolt/executor.rb:231:in `block (3 levels) in run_command'
/home/centos/source/bolt/lib/bolt/executor.rb:218:in `with_node_logging'
/home/centos/source/bolt/lib/bolt/executor.rb:230:in `block (2 levels) in run_command'
/home/centos/source/bolt/lib/bolt/executor.rb:82:in `block (3 levels) in queue_execute'
/home/centos/source/bolt/.bundle/gems/ruby/2.5.0/gems/concurrent-ruby-1.1.5/lib/concurrent/executor/ruby_thread_pool_executor.rb:348:in `run_task'
/home/centos/source/bolt/.bundle/gems/ruby/2.5.0/gems/concurrent-ruby-1.1.5/lib/concurrent/executor/ruby_thread_pool_executor.rb:337:in `block (3 levels) in create_worker'
/home/centos/source/bolt/.bundle/gems/ruby/2.5.0/gems/concurrent-ruby-1.1.5/lib/concurrent/executor/ruby_thread_pool_executor.rb:320:in `loop'
/home/centos/source/bolt/.bundle/gems/ruby/2.5.0/gems/concurrent-ruby-1.1.5/lib/concurrent/executor/ruby_thread_pool_executor.rb:320:in `block (2 levels) in create_worker'
/home/centos/source/bolt/.bundle/gems/ruby/2.5.0/gems/concurrent-ruby-1.1.5/lib/concurrent/executor/ruby_thread_pool_executor.rb:319:in `catch'
/home/centos/source/bolt/.bundle/gems/ruby/2.5.0/gems/concurrent-ruby-1.1.5/lib/concurrent/executor/ruby_thread_pool_executor.rb:319:in `block in create_worker'
/home/centos/source/bolt/.bundle/gems/ruby/2.5.0/gems/logging-2.2.2/lib/logging/diagnostic_context.rb:474:in `block in create_with_logging_context'
```

### Local Infra

In the event that it's desired to test winrm gem on Linux connecting to real Active Directory, rather than Samba... there are some hosts provisioned in Platform9. Ethan and Lucy currently have SSH access

```
ssh centos@10.234.1.22 -i ~/.ssh/id_rsa
klist
kinit -C Administrator@bolt.puppet
```

#### Domain admin

```
.\Administrator
Qu@lity!
```
