#!/usr/bin/env python
# my_app/tasks/healthcheck.py
# perform a healthcheck of a url

import json
import sys

json.dump(dict(status = "success"), sys.stdout)
