#!/bin/sh

if [ -z "$PT_message" ]; then
  echo "Need to pass a message"
  exit 1
fi

if [ -z "$PT_filename" ]; then
  echo "Need to pass a filename"
  exit 1
fi

echo $PT_message > "/tmp/${PT_filename}"
