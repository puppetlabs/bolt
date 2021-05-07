#!/bin/bash

if [[ $PT__noop == true ]]; then
  echo '{"noop":true}'
else
  echo '{"noop":false}'
fi
