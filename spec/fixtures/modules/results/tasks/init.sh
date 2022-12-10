#!/bin/sh

if [ ! -z "$PT_fail" ]; then
  exit 1
else
  echo "{\"tag\": \"you're it\"}"
fi
