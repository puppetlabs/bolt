#!/usr/bin/env python
# my_app/tasks/uninstall.py
# Remove and old version of the aplication

import json
import sys

json.dump(dict(status = "success"), sys.stdout)
