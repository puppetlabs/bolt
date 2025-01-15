# 2. Verify that bolt module dependencies are valid

Date: 2025-01-15

## Status

Accepted

## Context

Github actions do not currently verify whether bolt's module dependencies are valid.  In other worlds, bolt uses a number of puppet modules and these can be out-of-date or even missing dependencies.  This commit adds an extra step to CI that checks for missing dependecies.

## Decision

Add a step to the CI that checks for missing dependencies.

## Consequences

Bolt module dependencies will always be verified.
