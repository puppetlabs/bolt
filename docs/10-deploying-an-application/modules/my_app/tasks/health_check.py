#!/usr/bin/env python
# my_app/tasks/health_check.py
# perform a healthcheck of a url

import json
import sys

json.dump(dict(status = "success"), sys.stdout)
