#!/usr/bin/env python3
"""Applique une politique de connectivite (YAML) via l'API REST northbound d'ONOS."""
import sys

import requests
import yaml

ONOS = "http://127.0.0.1:8181/onos/v1"
AUTH = ("onos", "rocks")


def main(path):
    with open(path, encoding="utf-8") as f:
        policy = yaml.safe_load(f)
    for rule in policy["autorisations"]:
        intent = {
            "type": "HostToHostIntent",
            "appId": "org.onosproject.cli",
            "priority": rule.get("priorite", 100),
            "one": f"{rule['de']}/None",
            "two": f"{rule['vers']}/None",
        }
        r = requests.post(f"{ONOS}/intents", json=intent, auth=AUTH, timeout=5)
        print(f"{rule['nom']:<25} -> HTTP {r.status_code}")


if __name__ == "__main__":
    main(sys.argv[1])
