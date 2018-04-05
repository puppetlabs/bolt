#!/usr/bin/env python
# my_app/tasks/migrate.py
# Migrate DB schema

import json
import sys

params = json.load(sys.stdin)
json.dump(dict(status = "success"), sys.stdout)
