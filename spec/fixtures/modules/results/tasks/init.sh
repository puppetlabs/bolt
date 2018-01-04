#!/usr/bin/env/bash

echo "hi"

if [ -v $PT_fail ]; then
  exit 1
fi
