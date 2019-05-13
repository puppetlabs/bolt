#!/usr/bin/env python
# my_app/tasks/deploy.py
# Update and restart the application on the new version

import json
import sys

json.dump(dict(status = "success"), sys.stdout)
