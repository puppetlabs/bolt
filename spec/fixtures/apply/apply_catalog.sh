#!/bin/sh

echo '{"metrics": {}, "resource_statuses": {}, "status": "unchanged", "catalog":'
printenv PT_catalog
echo '}'
