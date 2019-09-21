#!/bin/sh

if [ -z "$PT_content" ]; then
  echo "Need to pass content"
  exit 1
fi

if [ -z "$PT_filename" ]; then
  echo "Need to pass a filename"
  exit 1
fi

echo $PT_content > "/tmp/${PT_filename}"
