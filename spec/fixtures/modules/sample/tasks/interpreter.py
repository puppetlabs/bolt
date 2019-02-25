#!/foo/python

import os
import fileinput
import json

for line in fileinput.input():
    input_data = json.loads(line)
    if input_data['message']:
    	print(json.dumps({'env': os.environ['PT_message'], 'stdin': input_data['message']}))
