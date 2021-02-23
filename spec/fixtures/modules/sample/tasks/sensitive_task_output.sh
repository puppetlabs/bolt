#!/usr/bin/env bash

if [[ -z $PT_include_sensitive ]]; then
  echo '{"user": "someone"}'
else
  echo '{"user": "someone", "_sensitive": { "password": "secretpassword" }}'
fi
