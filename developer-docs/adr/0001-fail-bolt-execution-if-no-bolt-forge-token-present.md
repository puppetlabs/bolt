# 1. Fail bolt execution if no BOLT_FORGE_TOKEN present

Date: 2024-11-26

## Status

Accepted

## Context

Bolt is moving from opensource to private.  One contraint is that users must have a forge token.  A simple way to enforce this is to ensure an environment variable is present containing a valid forge token.  Environment variables are recognized as a sensible and secure method for passing credentials into applications due to their simplicity, security, and flexibility.

## Decision

Therefore, I decided to pass forge token authentication via the `BOLT_FORGE_TOKEN` environment variable.

## Consequences

bolt operations will halt immediately in the absence of a valid environment variable and continue only if present. Downstream requests, e.g., to the forge, will include the `BOLT_FORGE_TOKEN` in all requests.  The environment variable makes it easy to run bolt manually or in a CI environment, like github where credentials are stored securely as environment variables alongside the action workflows.

See Appendix for a simple command-line example.

## Appendix

### Setup and Verification

#### Pre-requisites

Ensure these are installed:

* [rbenv](https://github.com/rbenv/rbenv)
* [direnv](https://direnv.net)
* `rbenv install 3.2.5`

#### Setup bolt before running tests


```bash
# configure rbenv, ruby 3.2.5, and direnv
rbenv local 3.2.5
echo "layout ruby" > .envrc
echo "use rbenv" >> .envrc
direnv allow

# configure bundle and install all bolt gem dependencies
bundle config --local gemfile Gemfile
bundle config --local path .direnv/ruby/gems
bundle config --local bin .direnv/bin
bundle install

# install local modules required for unit tests and validate module dependencies
bundle exec r10k puppetfile install
bundle exec puppet module list --tree --modulepath modules

# execute unit tests
bundle exec rake tests:unit
```

#### Verify CLI functionality

```bash
# Verify no token halts execution
bundle exec bolt command run 'echo hello' --targets localhost

# Verify "valid" token allows execution
BOLT_FORGE_TOKEN=validtoken123 bundle exec bolt command run 'echo hello' --targets localhost
```

For example,

```bash
# token not present: should fail
➜  bolt git:(development) bundle exec bolt command run 'echo hello' --targets localhost
BOLT_FORGE_TOKEN is not set

# token present: should succeed
➜  bolt git:(development) BOLT_FORGE_TOKEN=validtoken123 bundle exec bolt command run 'echo hello' --targets localhost
Started on localhost...
Finished on localhost:
  hello
Successful on 1 target: localhost
Ran on 1 target in 0.05 sec
➜  bolt git:(development) 
```
