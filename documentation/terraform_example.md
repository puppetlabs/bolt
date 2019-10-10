## Dynamic inventory with Terraform and pkcs7 plugins

Introduction to dynamic inventory...

### Setup

Link to terraform and docker install sites

#### Build Terraform manifest

This simple Terraform manifest will provision 3 docker containers running sshd on ubuntu. 

```hcl
# Configure the Docker provider
provider "docker" {}

# Create 3 sshd servers, map internal ports
resource "docker_container" "sshd" {
  image = "${docker_image.sshd.latest}"
  count = "3"
  name  = "docker_target_${count.index}"
  ports {
    internal = 22
    external = 2200 + count.index
  }
}

resource "docker_image" "sshd" {
  name = "rastasheep/ubuntu-sshd"
}
```
Ensure you have provider and provision
```
$terraform init

Initializing the backend...

Initializing provider plugins...

The following providers do not have any version constraints in configuration,
so the latest version was installed.

To prevent automatic upgrades to new major versions that may contain breaking
changes, it is recommended to add version = "..." constraints to the
corresponding provider blocks in configuration, with the constraint strings
suggested below.

* provider.docker: version = "~> 2.4"

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```
```
$terraform apply

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # docker_container.sshd[0] will be created
  + resource "docker_container" "sshd" {
      + attach           = false
      + bridge           = (known after apply)
      + container_logs   = (known after apply)
      + exit_code        = (known after apply)
      + gateway          = (known after apply)
      + id               = (known after apply)
      + image            = (known after apply)
      + ip_address       = (known after apply)
      + ip_prefix_length = (known after apply)
      + log_driver       = "json-file"
      + logs             = false
      + must_run         = true
      + name             = "docker_target_0"
      + network_data     = (known after apply)
      + restart          = "no"
      + rm               = false
      + start            = true

      + ports {
          + external = 2200
          + internal = 22
          + ip       = "0.0.0.0"
          + protocol = "tcp"
        }
    }

  # docker_container.sshd[1] will be created
  + resource "docker_container" "sshd" {
      + attach           = false
      + bridge           = (known after apply)
      + container_logs   = (known after apply)
      + exit_code        = (known after apply)
      + gateway          = (known after apply)
      + id               = (known after apply)
      + image            = (known after apply)
      + ip_address       = (known after apply)
      + ip_prefix_length = (known after apply)
      + log_driver       = "json-file"
      + logs             = false
      + must_run         = true
      + name             = "docker_target_1"
      + network_data     = (known after apply)
      + restart          = "no"
      + rm               = false
      + start            = true

      + ports {
          + external = 2201
          + internal = 22
          + ip       = "0.0.0.0"
          + protocol = "tcp"
        }
    }

  # docker_container.sshd[2] will be created
  + resource "docker_container" "sshd" {
      + attach           = false
      + bridge           = (known after apply)
      + container_logs   = (known after apply)
      + exit_code        = (known after apply)
      + gateway          = (known after apply)
      + id               = (known after apply)
      + image            = (known after apply)
      + ip_address       = (known after apply)
      + ip_prefix_length = (known after apply)
      + log_driver       = "json-file"
      + logs             = false
      + must_run         = true
      + name             = "docker_target_2"
      + network_data     = (known after apply)
      + restart          = "no"
      + rm               = false
      + start            = true

      + ports {
          + external = 2202
          + internal = 22
          + ip       = "0.0.0.0"
          + protocol = "tcp"
        }
    }

  # docker_image.sshd will be created
  + resource "docker_image" "sshd" {
      + id     = (known after apply)
      + latest = (known after apply)
      + name   = "rastasheep/ubuntu-sshd"
    }

Plan: 4 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

docker_image.sshd: Creating...
docker_image.sshd: Creation complete after 6s [id=sha256:49533628fb371c9f1952c06cedf912c78a81fbe3914901334673c369376e077erastasheep/ubuntu-sshd]
docker_container.sshd[2]: Creating...
docker_container.sshd[0]: Creating...
docker_container.sshd[1]: Creating...
docker_container.sshd[2]: Creation complete after 1s [id=268e5d2572d7610f88d977b8bd37896830e6aa4777b0c7aded5e29b5fb8b0fb2]
docker_container.sshd[1]: Creation complete after 1s [id=3e32b6d85cfdfaa823bfd3148aa0c9772ae1d896e993508d44088927406b95a5]
docker_container.sshd[0]: Creation complete after 1s [id=f04670444f710a646d7994a9cb5a60d5b0ef42ce915df9e713f324340bb1dbfa]

Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```
Check that containers are running
```
$ docker ps
CONTAINER ID        IMAGE               COMMAND               CREATED              STATUS              PORTS                  NAMES
3e32b6d85cfd        49533628fb37        "/usr/sbin/sshd -D"   About a minute ago   Up About a minute   0.0.0.0:2201->22/tcp   docker_target_1
f04670444f71        49533628fb37        "/usr/sbin/sshd -D"   About a minute ago   Up About a minute   0.0.0.0:2200->22/tcp   docker_target_0
268e5d2572d7        49533628fb37        "/usr/sbin/sshd -D"   About a minute ago   Up About a minute   0.0.0.0:2202->22/tcp   docker_target_2
```

### Now try connecting with bolt
First test a connection with docker transport
```
$ bolt command run hostname -t 3e32b6d85cfd --transport docker
Started on 3e32b6d85cfd...
Finished on 3e32b6d85cfd:
  STDOUT:
    3e32b6d85cfd
Successful on 1 node: 3e32b6d85cfd
Ran on 1 node in 0.46 sec
```
Now test ssh over bolt
```
bolt command run hostname -t ssh://root:root@0.0.0.0:2201
Started on ssh://root@0.0.0.0:2201...
Finished on ssh://root@0.0.0.0:2201:
  STDOUT:
    3e32b6d85cfd
Successful on 1 node: ssh://root@0.0.0.0:2201
Ran on 1 node in 0.2 sec
```
### Build inventory
TODO: Detail how to build an inventory for the above examples and progressively switch to dynamic (this will ensure the nice safe_names being printed. So maybe dont even do the CLI examples until we build inventory)
TODO: go over project structure???? 

TODO: explain how to map out where to find info in tfstate, tfstate snipit
```
{
  "version": 4,
  "terraform_version": "0.12.10",
  "serial": 45,
  "lineage": "f4c7f41c-5e35-ceac-b717-d13da76dd5ef",
  "outputs": {},
  "resources": [
    {
      "mode": "managed",
      "type": "docker_container",
      "name": "sshd",
      "each": "list",
      "provider": "provider.docker",
      "instances": [
        {
          "index_key": 0,
          "schema_version": 1,
          "attributes": {
            "attach": false,
            "bridge": "",
            "capabilities": [],
            "command": null,
            "container_logs": null,
            "cpu_set": null,
            "cpu_shares": null,
            "destroy_grace_seconds": null,
            "devices": [],
            "dns": null,
            "dns_opts": null,
            "dns_search": null,
            "domainname": null,
            "entrypoint": null,
            "env": null,
            "exit_code": null,
            "gateway": "172.17.0.1",
            "group_add": null,
            "healthcheck": [],
            "host": [],
            "hostname": null,
            "id": "f04670444f710a646d7994a9cb5a60d5b0ef42ce915df9e713f324340bb1dbfa",
            "image": "sha256:49533628fb371c9f1952c06cedf912c78a81fbe3914901334673c369376e077e",
            "ip_address": "172.17.0.4",
            "ip_prefix_length": 16,
            "ipc_mode": null,
            "labels": null,
            "links": null,
            "log_driver": "json-file",
            "log_opts": null,
            "logs": false,
            "max_retry_count": null,
            "memory": null,
            "memory_swap": null,
            "mounts": [],
            "must_run": true,
            "name": "docker_target_0",
            "network_alias": null,
            "network_data": [
              {
                "gateway": "172.17.0.1",
                "ip_address": "172.17.0.4",
                "ip_prefix_length": 16,
                "network_name": "bridge"
              }
            ],
            "network_mode": null,
            "networks": null,
            "networks_advanced": [],
            "pid_mode": null,
            "ports": [
              {
                "external": 2200,
                "internal": 22,
                "ip": "0.0.0.0",
                "protocol": "tcp"
              }
            ],
            "privileged": null,
            "publish_all_ports": null,
            "restart": "no",
            "rm": false,
            "shm_size": null,
            "start": true,
            "sysctls": null,
            "tmpfs": null,
            "ulimit": [],
            "upload": [],
            "user": null,
            "userns_mode": null,
            "volumes": [],
            "working_dir": null
          },
          "private": "eyJzY2hlbWFfdmVyc2lvbiI6IjEifQ==",
          "depends_on": [
            "docker_image.sshd"
          ]
        },
```
### Invnetory

Show how to map values in example snipit to this (showing remote, could do statefile)
```yaml
version: 2
groups:
  - name: terraform-group
    targets:
      - _plugin: terraform
        dir: /home/cas/working_dir/dynamic-inventory-demo
        resource_type: docker_container.sshd.*
        # statefile: test/terraform_local.tfstate
        backend: remote
        uri: network_data.0.gateway
        name: name
        config:
          ssh:
            port: ports.0.external
    config:
      transport: ssh
      ssh:
        user: root
        password: root
```
try it out
```
cas@cas-ThinkPad-T460p:~/working_dir/bolt$ PATH=$PATH:~/working_dir/dynamic-inventory-demo/terraform bolt command run hostname -t terraform-group
Started on docker_target_0...
Started on docker_target_2...
Started on docker_target_1...
Finished on docker_target_0:
  STDOUT:
    f04670444f71
Finished on docker_target_2:
  STDOUT:
    268e5d2572d7
Finished on docker_target_1:
  STDOUT:
    3e32b6d85cfd
Successful on 3 nodes: docker_target_0,docker_target_1,docker_target_2
Ran on 3 nodes in 0.27 sec
```

### PKCS7 plugin
Now pretend we want to protect that ssh password

Configure pkcs7 in bolt.yaml
```yaml
plugins:
  pkcs7:
    private-key: ~/working_dir/dynamic-inventory-demo/keys/public.pkcs7.pem
    public-key: ~/working_dir/dynamic-inventory-demo/keys/private.pkcs7.pem
    keysize: 4096
```
Generate keys
```
$ bolt secret createkeys
$ ls ~/working_dir/dynamic-inventory-demo/keys
private.pkcs7.pem  public.pkcs7.pem
```
Encrypt password

```
$ bolt secret encrypt root
ENC[PKCS7,MIICeQYJKoZIhvcNAQcDoIICajCCAmYCAQAxggIhMIICHQIBADAFMAACAQEw
DQYJKoZIhvcNAQEBBQAEggIAY2FIHgScXnMhAf2XZGC1Oae8llfEUIWsurss
Ygtc5nN1yIJkCY3IU72WhDpNgPeiFThlxXgt5KwhudxAjnisnjB0lRlzzhzX
heyPh6XFd4EG8AK4ty/s+1bf+TfYq0EY/C6mPbynLYYDXlR+IkCm/5Z5lo0n
6KQjAmdTUlJx1aCY9lcyK0QZ9erznGFxCyuYwsOGAx+j+52wIoGLp3WS4aHa
XCKlecD9ylvohK/ZSW2pQcFOF71JHvrJUjnWrQ9ONoIIGrzpUIaTbUDD/w2n
oVRUFUW/Hx4sMhwU0E0ozTesPcI+yFQPDXhJxvXl15fdzv0hIJ6Moml13MRP
m3r9U+MK5x9//CGAym7v774/A+8+V97NCW7VW6X1XapIX9RM52FY4ZG3k9sp
XtnIRGFmNyjz0q1PC1ZuSAulb+RNwLjpVay6RcGydHaIJZ7AqPknA4nSN7Ye
D49DYl/tSkDdZKU0FXuF0gWBPv52y2t46YnXcBTDArxBqQjRsON+XWyd/9t5
YYVvWx97oRa6XHdZnRX9KDDXeKWH0e+kzEop6hPJaNOsmSlMJCn3OSyvLJdw
zYatllKZF+2iSVf2SYTtGqTL4wLs50164+kwUsem1IwlzAgpj0FLw+quQxWX
CPACM2l0cfIA+fjLxpE7ot5aTymwybtW7EorfmXc5KyfLWIwPAYJKoZIhvcN
AQcBMB0GCWCGSAFlAwQBKgQQwml96nDZqkQmy4dGIch4NYAQQiu3tflL9OqW
iV8egTT6Yw==]
```
Add to inventory
```yaml
version: 2
groups:
  - name: terraform-group
    targets:
      - _plugin: terraform
        dir: /home/cas/working_dir/dynamic-inventory-demo
        resource_type: docker_container.sshd.*
        # statefile: test/terraform_local.tfstate
        backend: remote
        uri: network_data.0.gateway
        name: name
        config:
          ssh:
            port: ports.0.external
    config:
      transport: ssh
      ssh:
        user: root
        password: 
          _plugin: pkcs7
          encrypted_value:
            ENC[PKCS7,MIICeQYJKoZIhvcNAQcDoIICajCCAmYCAQAxggIhMIICHQIBADAFMAACAQEw
            DQYJKoZIhvcNAQEBBQAEggIAY2FIHgScXnMhAf2XZGC1Oae8llfEUIWsurss
            Ygtc5nN1yIJkCY3IU72WhDpNgPeiFThlxXgt5KwhudxAjnisnjB0lRlzzhzX
            heyPh6XFd4EG8AK4ty/s+1bf+TfYq0EY/C6mPbynLYYDXlR+IkCm/5Z5lo0n
            6KQjAmdTUlJx1aCY9lcyK0QZ9erznGFxCyuYwsOGAx+j+52wIoGLp3WS4aHa
            XCKlecD9ylvohK/ZSW2pQcFOF71JHvrJUjnWrQ9ONoIIGrzpUIaTbUDD/w2n
            oVRUFUW/Hx4sMhwU0E0ozTesPcI+yFQPDXhJxvXl15fdzv0hIJ6Moml13MRP
            m3r9U+MK5x9//CGAym7v774/A+8+V97NCW7VW6X1XapIX9RM52FY4ZG3k9sp
            XtnIRGFmNyjz0q1PC1ZuSAulb+RNwLjpVay6RcGydHaIJZ7AqPknA4nSN7Ye
            D49DYl/tSkDdZKU0FXuF0gWBPv52y2t46YnXcBTDArxBqQjRsON+XWyd/9t5
            YYVvWx97oRa6XHdZnRX9KDDXeKWH0e+kzEop6hPJaNOsmSlMJCn3OSyvLJdw
            zYatllKZF+2iSVf2SYTtGqTL4wLs50164+kwUsem1IwlzAgpj0FLw+quQxWX
            CPACM2l0cfIA+fjLxpE7ot5aTymwybtW7EorfmXc5KyfLWIwPAYJKoZIhvcN
            AQcBMB0GCWCGSAFlAwQBKgQQwml96nDZqkQmy4dGIch4NYAQQiu3tflL9OqW
            iV8egTT6Yw==]
```
Prove it
```
$ bolt command run hostname -t terraform-group
Started on docker_target_0...
Started on docker_target_2...
Started on docker_target_1...
Finished on docker_target_2:
  STDOUT:
    268e5d2572d7
Finished on docker_target_0:
  STDOUT:
    f04670444f71
Finished on docker_target_1:
  STDOUT:
    3e32b6d85cfd
Successful on 3 nodes: docker_target_0,docker_target_1,docker_target_2
Ran on 3 nodes in 0.26 sec
```