#! /usr/bin/env python

"""
This script returns a JSON string with a single key, answer which
has a boolean value. It should flip between returning true and false
at random
"""

import json
import random

print(json.dumps({'answer': bool(random.getrandbits(1))}))
