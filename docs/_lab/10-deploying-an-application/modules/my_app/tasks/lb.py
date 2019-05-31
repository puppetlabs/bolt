#!/usr/bin/env python
# my_app/tasks/lb.py
# manipulate load_balancer

import json
import sys

from random import randint
from time import sleep

params = json.load(sys.stdin)

def stats():
    return { "connections": randint(0, 10), "status": "ok" }

def drain():
    sleep(3)
    return { "status": "success"}

def add():
    return { "status": "success" }

result_fn  = {
  "stats" : stats,
  "drain": drain,
  "add" : add,
}[params["action"]]

json.dump(result_fn(), sys.stdout)
