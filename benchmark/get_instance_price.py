"""
Find the on-demand price per hour for an instance, using the supplied command
line arguments:
 - provider, region, instance type
Using the KEY and SECRET environment variables to access the platform.
"""

import json
from os import getenv
from sys import argv

import requests

try:
    result = requests.get(
        url="https://portal.yellowdog.co/api/cloudInfo/instanceTypePrices",
        headers={"Authorization": f"yd-key {getenv('KEY')}:{getenv('SECRET')}"},
        params={
            "providers": [argv[1]],
            "region": argv[2],
            "instanceType": argv[3],
            "usageTypes": ["ON_DEMAND"],
            "operatingSystemLicences": ["NONE"],
        },
        timeout=20.0,
    )
    data = json.loads(result.text)
    currency = data["items"][0]["price"]["currency"]
    price = str(data["items"][0]["price"]["value"])
    print(f"{currency} {price}")
except:
    print("No price found")
