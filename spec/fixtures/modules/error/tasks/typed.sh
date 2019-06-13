#!/usr/bin/env bash

if [ "$PT_fail" = true ]; then
  exit 1
else
  echo "{\"tag\": \"you're it\"}"
fi
