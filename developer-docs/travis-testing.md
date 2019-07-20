# Travis testing instructions

### Start in debug mode

https://docs.travis-ci.com/user/running-build-in-debug-mode/

```
curl -s -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Travis-API-Version: 3" -H "Authorization: token XXXXXXXXXXXX" -d '{ "quiet": true }' https://api.travis-ci.org/job/XXXXXXXXXXX/debug
```

Look at bottom of logs for preserved host

```
ssh foo@to2.tmate.io
```

Can use `tmate` to run multiple windows, manage like this:

* ctrl-b c - new window
* ctrl-b 0
* ctrl-b 1 etc

There are some special helpers available to provision things:

```
travis_run_before_install
```

To do useful things with bolt, probably want to do this :

```
cat << EOF>Gemfile.local
gem "pry-byebug"
gem 'pry-stack_explorer'
EOF

bundle update
```

To fire up omiserver (`samba-ad` container should be started by `travis_run_before_install`)

```
docker-compose -f spec/docker-compose.yml up --build samba-ad omiserver
```


Grab the Kerberos ticket

```
echo 'B0ltrules!' | kinit Administrator@BOLT.TEST
klist
```

Code that may be useful to edit

```
/home/travis/.rvm/gems/ruby-2.5.5/gems/winrm-2.3.2/lib/winrm/http/transport.rb
```


#### Useful testing commands

Make sure realm is configured

```
mkdir -p ~/.puppetlabs/bolt
cat << EOF>~/.puppetlabs/bolt/bolt.yaml
---
winrm:
  realm: BOLT.TEST
EOF
```

HTTPS

```
bundle exec bolt command run "whoami" --nodes winrm://omiserver.bolt.test:45986 --debug --verbose --connect-timeout 9999 --no-ssl-verify
```

regular HTTP

```
bundle exec bolt command run "whoami" --nodes winrm://omiserver.bolt.test:45985 --debug --verbose --connect-timeout 9999 --no-ssl
```
