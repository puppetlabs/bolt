#!/usr/bin/env bash
for var in "$@"
do
    echo "arg: $var"
done

echo "standard out"
echo "standard error" >&2
