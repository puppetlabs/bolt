#!/usr/bin/env python
# my_app/tasks/install.py
# Install application

import json
import sys

params = json.load(sys.stdin)
json.dump(dict(status = "success", previous_version = "1.0.0", new_version = params['version']), sys.stdout)
