import json
import os
import requests

def handler(event, context):
    print("Received event: " + json.dumps(event, indent=2))
    r = requests.post(url = os.environ['ENDPOINT'], data = event)
    print("Response: " + r.text)


